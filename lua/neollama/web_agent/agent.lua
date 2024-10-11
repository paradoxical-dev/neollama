local job = require("plenary.job")
local prompts = require("neollama.web_agent.prompts")
local utils = require("neollama.utils")
local plugin = require("neollama.init")

local M = {}

-- Prompts the buffer agent to decide whether a web search is needed; provides queries if so
M.requires_current_data = function(user_prompt)
	local res
	local model
	if not plugin.config.web_agent.use_current then
		model = plugin.config.web_agent.buffer_agent
	end

	local port = plugin.config.local_port .. "/chat"
	local params = {
		model = model or _G.NeollamaModel, -- replace with configured model,
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
				res = vim.json.decode(raw_response.message.content)
				M.web_search = res
			else
				print("curl command failed with exit code: ", return_val)
			end
		end,
	}):start()
end

-- Uses the ddgr command to find the top search results for the passed query
M.generate_search_results = function(query)
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
				print(vim.inspect(json_resp))
			else
				print("ddgr command failed with exit code: ", return_val)
			end
		end,
	}):start()
end

-- M.requires_current_data("What is the current price of Ethereum?")
-- if M.web_search then
-- 	if M.web_search.needs_web_search then
-- 		M.generate_search_results(M.web_search.queries[1])
-- 	else
-- 		print("No web search needed")
-- 	end
-- else
-- 	utils.setTimeout(0.2, function()
-- 		if M.web_search.needs_web_search then
-- 			M.generate_search_results(M.web_search.queries[1])
-- 		else
-- 			print("No web search needed")
-- 		end
-- 	end, function()
-- 		return M.web_search
-- 	end)
-- end

return M
