local job = require("plenary.job")
local prompts = require("neollama.web_agent.prompts")
-- local scraper = require("neollama.web_agent.scraper")

local M = {}

local plugin

M.set_plugin = function(init)
	plugin = init
end

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

M.compilation_agent = function(user_prompt, content)
	local res
	local model
	if not plugin.config.web_agent.use_current then
		model = plugin.config.web_agent.reviewing_agent
	end

	local port = plugin.config.local_port .. "/chat"
	local params = {
		model = model or _G.NeollamaModel,
		messages = {
			{ role = "system", content = prompts.compile_info(user_prompt) },
			{ role = "user", content = content },
		},
		stream = false,
		options = {
			num_ctx = 4096,
		},
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
				print("Compiled Response: ", vim.inspect(res))
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

return M
