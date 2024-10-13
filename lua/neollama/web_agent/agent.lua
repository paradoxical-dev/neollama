local job = require("plenary.job")
local prompts = require("neollama.web_agent.prompts")
local utils = require("neollama.utils")
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
			{ role = "user",   content = user_prompt },
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

-- test usage
M.buffer_agent("What is the current price of Ethereum?", function(res)
	if res.needs_web_search then
		scraper.generate_search_results(res.queries[1], function(search_results)
			scraper.scrape_website_content(search_results[2].url, {}, function(status)
				if status then
					print("Web search succeeded: ", status.content)
					print("Source: ", status.source)
					print(vim.inspect(status))
				else
					print("Web search failed")
					print(vim.inspect(status))
				end
			end)
		end)
	else
		print("No web search needed")
	end
end)

return M
