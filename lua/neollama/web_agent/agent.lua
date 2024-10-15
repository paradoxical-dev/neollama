-- TODO: integration agent to compile response from content. This agent should be capable of providing feedback if more content is needed
-- TODO: implement a retry system for failed sites. The failed sites should be stored in a table for 'per session' use or a JSON file for persistent use

local job = require("plenary.job")
local prompts = require("neollama.web_agent.prompts")
local plugin = require("neollama.init")
local scraper = require("neollama.web_agent.scraper")

local M = {}

-- Prompts the buffer agent to decide whether a web search is needed; provides queries if so
-- Callback is used to handle the returned data
M.buffer_agent = function(user_prompt, cb)
	local res
	local model
	if not plugin.config.web_agent.use_current then
		model = plugin.config.web_agent.buffer_agent
	end

	local port = plugin.config.local_port .. "/chat"
	local params = {
		model = model or _G.NeollamaModel,
		messages = {
			{ role = "system", content = prompts.requires_current_data },
			{ role = "user", content = user_prompt },
		},
		format = "json",
		stream = false,
	}
	local args = {
		"--silent",
		"--show-error",
		"--no-buffer",
		port,
		"-H",
		"Content-Type: application/json",
		"-d",
		vim.json.encode(params),
	}
	job:new({
		command = "curl",
		args = args,
		cwd = "/usr/bin",
		on_stderr = function(err)
			print("Error: ", err)
		end,
		on_exit = function(j, return_val)
			if return_val == 0 then
				local raw_response = vim.json.decode(j:result()[1])
				if raw_response.error then
					print("Ollama API error: ", vim.inspect(raw_response))
					return
				end

				res = vim.json.decode(raw_response.message.content)
				cb(res)
			else
				print("curl command failed with exit code: ", return_val)
			end
		end,
	}):start()
end

M.integration_agent = function(user_prompt, site_content)
	local res
	local model
	if not plugin.config.web_agent.use_current then
		model = plugin.config.web_agent.integration_agent
	end

	local port = plugin.config.local_port .. "/chat"
	local params = {
		model = model or _G.NeollamaModel,
		messages = {
			{ role = "system", content = prompts.integration_prompt(user_prompt) },
			{ role = "user", content = site_content },
		},
		stream = plugin.config.params.stream,
	}
	local args = {
		"--silent",
		"--show-error",
		"--no-buffer",
		port,
		"-H",
		"Content-Type: application/json",
		"-d",
		vim.json.encode(params),
	}
	job:new({
		command = "curl",
		args = args,
		cwd = "/usr/bin",
		on_stderr = function(err)
			print("Error: ", err)
		end,
		on_exit = function(j, return_val)
			if return_val == 0 then
				local raw_response = vim.json.decode(j:result()[1])
				if raw_response.error then
					print("Ollama API error: ", vim.inspect(raw_response))
					return
				end

				res = raw_response.message.content
				print("Integration Response: ", res)
				-- M.res_check_agent(user_prompt, res)
			else
				print("curl command failed with exit code: ", return_val)
			end
		end,
	}):start()
end

M.site_select = function(user_prompt, search_results, cb)
	local res
	local model
	if not plugin.config.web_agent.use_current then
		model = plugin.config.web_agent.buffer_agent
	end

	local port = plugin.config.local_port .. "/chat"
	local params = {
		model = model or _G.NeollamaModel,
		messages = {
			{ role = "system", content = prompts.site_select(user_prompt) },
			{ role = "user", content = search_results },
		},
		stream = false,
	}
	local args = {
		"--silent",
		"--show-error",
		"--no-buffer",
		port,
		"-H",
		"Content-Type: application/json",
		"-d",
		vim.json.encode(params),
	}
	job:new({
		command = "curl",
		args = args,
		cwd = "/usr/bin",
		on_stderr = function(err)
			print("Error: ", err)
		end,
		on_exit = function(j, return_val)
			if return_val == 0 then
				local raw_response = vim.json.decode(j:result()[1])
				if raw_response.error then
					print("Ollama API error: ", vim.inspect(raw_response))
					return
				end

				res = raw_response.message.content
				cb(res)
			else
				print("curl command failed with exit code: ", return_val)
			end
		end,
	}):start()
end

M.res_check_agent = function(user_prompt, response)
	local res
	local model
	if not plugin.config.web_agent.use_current then
		model = plugin.config.web_agent.reviewing_agent
	end

	local port = plugin.config.local_port .. "/chat"
	local params = {
		model = model or _G.NeollamaModel,
		messages = {
			{ role = "system", content = prompts.response_checker_prompt(user_prompt) },
			{ role = "user", content = response },
		},
		format = "json",
		stream = false,
	}
	local args = {
		"--silent",
		"--show-error",
		"--no-buffer",
		port,
		"-H",
		"Content-Type: application/json",
		"-d",
		vim.json.encode(params),
	}
	job:new({
		command = "curl",
		args = args,
		cwd = "/usr/bin",
		on_stderr = function(err)
			print("Error: ", err)
		end,
		on_exit = function(j, return_val)
			if return_val == 0 then
				local raw_response = vim.json.decode(j:result()[1])
				if raw_response.error then
					print("Ollama API error: ", vim.inspect(raw_response))
					return
				end

				res = vim.json.decode(raw_response.message.content)
				print("Review Response: ", vim.inspect(res))
			else
				print("curl command failed with exit code: ", return_val)
			end
		end,
	}):start()
end

M.use_web_agent = function(user_prompt)
	M.buffer_agent(user_prompt, function(res)
		if res.needs_web_search then
			for _, query in ipairs(res.queries) do
				scraper.generate_search_results(query, function(search_results)
					M.site_select(user_prompt, search_results, function(site_url)
						print("Site URL: ", site_url)
						return site_url
					end)
				end)
			end
		else
			return false
		end
	end)
end

-- test usage
-- local user_prompt = "What is the current price of Ethereum?"
-- M.buffer_agent(user_prompt, function(res)
-- 	if res.needs_web_search then
-- 		scraper.generate_search_results(res.queries[1], function(search_results)
-- 			scraper.scrape_website_content(search_results[2].url, {}, function(status)
-- 				if status then
-- 					M.integration_agent(user_prompt, status.content)
-- 				else
-- 					print("Web search failed")
-- 				end
-- 			end)
-- 		end)
-- 	else
-- 		print("No web search needed")
-- 	end
-- end)

return M
