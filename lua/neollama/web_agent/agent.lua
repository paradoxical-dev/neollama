local job = require("plenary.job")
local prompts = require("neollama.web_agent.prompts")
local utils = require("neollama.utils")

local M = {}

M.requires_current_data = function(user_prompt)
	local res
	local port = "http://localhost:11434/api/chat"
	local params = {
		model = "llama3.1", -- replace with configured model,
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
				res = vim.json.decode(raw_response.message.content)
				M.web_search = res
			else
				print("Curl command failed with exit code: ", return_val)
			end
		end,
	}):start()
end

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
				M.web_search = json_resp
				print(vim.inspect(json_resp))
			else
				print("ddgr command failed with exit code: ", return_val)
			end
		end,
	}):start()
end
M.generate_search_results("What is the current weather in London?")

return M
