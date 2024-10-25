local gumbo = require("gumbo")
local job = require("plenary.job")

local M = {}
local plugin

M.set_plugin = function(init)
	plugin = init
end

-- Makes the search results readable for ollama
local function format_search_results(search_results)
	local formatted = [[]]
	for index, value in ipairs(search_results) do
		formatted = formatted
				.. "\n\n"
				.. "Option "
				.. index
				.. ": "
				.. "\n"
				.. "Title: "
				.. value.title
				.. "\n"
				.. "Description: "
				.. value.abstract
				.. "\n"
				.. "URL: "
				.. value.url
	end

	return formatted
end

-- Uses the ddgr command to find the top search results for the passed query
-- Callback is used to handle the returned data
M.generate_search_results = function(query, cb)
	job:new({
		command = "ddgr",
		args = {
			"--json",
			query,
		},
		cwd = "/usr/bin",
		on_exit = function(j, return_val)
			if return_val == 0 then
				local result = j:result()
				local json_resp = vim.json.decode(table.concat(result, "\n"))
				local formatted = format_search_results(json_resp)

				cb(formatted)
			else
				print("ddgr command failed with exit code: ", return_val, "\nError: " .. table.concat(j:result(), "\n"))
			end
		end,
	}):start()
end

local function is_visible_tag(tag)
	local visible_tags = {
		"p",
		"div",
		"span",
		"a",
		"h1",
		"h2",
		"h3",
		"h4",
		"h5",
		"h6",
		"li",
		"ul",
		"ol",
		"strong",
		"em",
		"b",
		"i",
		"pre",
		"code",
		"main",
		"section",
		"article",
		"details",
		"summary",
		"aside",
		"figure",
		"figcaption",
		"blockquote",
		"mark",
		"dl",
		"dt",
		"dd",
		"header",
		"footer",
		"nav",
	}
	for _, visible_tag in ipairs(visible_tags) do
		if tag == visible_tag then
			return true
		end
	end

	-- typical format for custom framework tags
	if tag:find("-") then
		return true
	end

	return false
end

-- Recursivley parses the passed HTML body and returns the text
local function extract_text(node)
	if node.type == "element" and (node.tagName == "SCRIPT" or node.tagName == "STYLE") then
		return ""
	end

	if node.type == "text" then
		return node.data
	end

	local text = {}
	if (node.type == "element" and is_visible_tag(node.tagName:lower())) or node.tagName == "BODY" then
		for _, child in ipairs(node.childNodes) do
			table.insert(text, extract_text(child))
		end
	end

	return table.concat(text, " ")
end

-- Formats text and sets context limit
local function clean_text(content)
	-- Make multi space words to single space
	local shrunk_text = content:gsub("%s+", " ")
	local split_text = {}

	for word in shrunk_text:gmatch("%S+") do
		table.insert(split_text, word)
		-- Context limit
		if #split_text > plugin.config.web_agent.content_limit then
			break
		end
	end

	local cleaned = table.concat(split_text, " ")
	return cleaned
end

-- Stores the current attempt | Is reset on success
M.retry_count = 1
M.failed_sites = {}

-- Grabs the text from the website and passes to callback
local function request_site(url, cb)
	local args = {
		"--request",
		"GET",
		"--url",
		url,
		"--header",
		"User-Agent: " .. plugin.config.web_agent.user_agent,
		"--header",
		"Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9",
		"--header",
		"Accept-Language: en-US,en;q=0.9",
		"--header",
		"Referer: https://www.google.com/",
		"--header",
		"Connection: keep-alive",
		"--header",
		"Upgrade-Insecure-Requests: 1",
		"--max-time",
		plugin.config.web_agent.timeout,
	}

	job:new({
		command = "curl",
		args = args,
		cwd = "/usr/bin",
		on_stderr = function(err)
			if err ~= nil then
				print("Error: ", err)
			end
		end,
		on_exit = function(j, return_val)
			if return_val == 0 then
				local html = table.concat(j:result(), "\n")
				if #html == 0 then
					M.retry_count = 1
					cb(false)
					return
				end
				local document = gumbo.parse(html)
				local dirty_text = extract_text(document.body)
				local cleaned_text = clean_text(dirty_text)

				M.retry_count = 1
				cb(cleaned_text)
			else
				print(
					"Curl command failed with exit code: ",
					return_val .. "\nResponse: " .. table.concat(j:result(), "\n")
				)
				print("Retrying...")
				M.retry_count = M.retry_count + 1
				if M.retry_count <= plugin.config.web_agent.retry_count then
					request_site(url, cb)
				else
					print("Failed to scrape website: " .. url .. " after " .. M.retry_count .. " retries")
					M.retry_count = 1
					cb(false)
				end
			end
		end,
	}):start()
end

-- Function to check if text is readable to Ollama
local function is_garbled(text)
	local non_ascii_count = 0
	for i = 1, #text do
		local char = text:sub(i, i)
		if not char:match("%g") then
			non_ascii_count = non_ascii_count + 1
		end
	end
	return non_ascii_count / #text > 0.2
end

---@param website_url string
---@param failed_sites table
---@param cb function (Will handle the result of the main function returning either false or table of website_url and content)
M.scrape_website_content = function(website_url, failed_sites, cb)
	failed_sites = failed_sites or {}
	local status

	request_site(website_url, function(cleaned_text)
		if not cleaned_text then
			table.insert(failed_sites, website_url)
			status = false
			cb(status)
			return
		end

		if is_garbled(cleaned_text) then
			table.insert(failed_sites, website_url)
			status = false
		else
			status = {
				source = website_url,
				content = cleaned_text,
			}
		end

		cb(status)
	end)
end

return M
