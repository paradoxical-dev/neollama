local job = require("plenary.job")
local prompts = require("neollama.web_agent.prompts")
local scraper = require("neollama.web_agent.scraper")

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

-- Creates the final response to the users input using the compiled information from the feedback loop
-- Will be treated the same as the standard Ollama call with its final response appended to the chat history
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
			{ role = "user",   content = site_content },
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

-- Selects the best url from the search results using the titles and descriptions
-- Returns the selected url
M.site_select = function(user_prompt, search_results, failed_sites, cb)
	local res
	local model
	if not plugin.config.web_agent.use_current then
		model = plugin.config.web_agent.buffer_agent
	end

	local port = plugin.config.local_port .. "/chat"
	local params = {
		model = model or _G.NeollamaModel,
		messages = {
			{ role = "system", content = prompts.site_select(user_prompt, failed_sites) },
			{ role = "user",   content = search_results },
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

-- Compiles the scrpaed content to only include relevant information
M.compilation_agent = function(user_prompt, content, cb)
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
			{ role = "user",   content = content },
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
				cb(res)
			else
				print("Curl command failed with exit code: ", return_val)
			end
		end,
	}):start()
end

-- Decides if the scraped content is enough to answer the user input
-- Will be used in the feedback loop to continue the compilation of information using other queries
M.res_check_agent = function(user_prompt, content, cb)
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
			{ role = "user",   content = content },
		},
		format = "json",
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

				res = vim.json.decode(raw_response.message.content)
				print("Review Response: ", vim.inspect(res))
				cb(res)
			else
				print("curl command failed with exit code: ", return_val)
			end
		end,
	}):start()
end

-- Stores the current query index and compiled information for the feedback loop
M.query_index = 1
M.compiled_information = [[]]

-- Combines the agent calls to simulate a feedback loop
-- Reruns the function in the case that the information is inadequate or the chose site failed
M.feedback_loop = function(value, res)
	if M.query_index > #res.queries then
		return
	end
	scraper.generate_search_results(res.queries[M.query_index], function(search_results)
		M.site_select(value, search_results, scraper.failed_sites, function(url)
			for _, site in ipairs(scraper.failed_sites) do
				if url == site then
					if M.query_index <= #res.queries then
						M.query_index = M.query_index + 1
						M.feedback_loop(value, res)
					end
					return
				end
			end
			scraper.scrape_website_content(url, scraper.failed_sites, function(status)
				if not status then
					print("failed to get content")
					if M.query_index <= #res.queries then
						M.query_index = M.query_index + 1
						M.feedback_loop(value, res)
					end
				else
					M.compilation_agent(value, status.content, function(compiled_information)
						M.compiled_information = M.compiled_information .. compiled_information
						M.res_check_agent(value, M.compiled_information, function(check)
							if check.res_passed then
								print("information is good")
							else
								print("information is bad")
								if M.query_index <= #res.queries then
									M.query_index = M.query_index + 1
									M.feedback_loop(value, res)
								end
							end
						end)
					end)
				end
			end)
		end)
	end)
end

return M
