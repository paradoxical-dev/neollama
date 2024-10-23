local Input = require("nui.input")
local utils = require("neollama.utils")
local NuiText = require("nui.text")
-- local web_agent = require("neollama.web_agent")

local M = {}

local API
local LayoutHandler
local plugin
local web_agent
local scraper

M.set_api = function(api)
	API = api
end

M.set_layout_handler = function(handler)
	LayoutHandler = handler
end

M.set_plugin = function(init)
	plugin = init
end

M.set_agent = function(agent)
	web_agent = agent
end

-- Call the necessary functions to update the UI and set the api state
local function ui_update()
	vim.schedule(function()
		LayoutHandler.show_input()
		LayoutHandler.update_window_selection()
	end, 0)

	vim.schedule(function()
		utils.reformat_session(API.params.messages)
	end, 0)

	utils.setTimeout(0.25, function()
		vim.api.nvim_set_current_win(plugin.input.winid)
	end, function()
		return vim.api.nvim_win_is_valid(plugin.input.winid)
	end)

	API.done = false
end

-- The set of functions for the standard model call
local function model_call()
	-- check if model is loaded before calling ollama client
	if API.model_loaded then
		API.ollamaCall()
	else
		utils.setTimeout(0.25, function()
			print("Delayed start: Model loading")
			API.ollamaCall()
		end, function()
			return API.model_loaded
		end)
	end

	-- check if full response has been generated before updating the UI
	if API.done then
		ui_update()
	else
		utils.setTimeout(0.5, function()
			ui_update()
		end, function()
			return API.done
		end)
	end

	-- update the window selection and reset session keymaps
	vim.schedule(function()
		LayoutHandler.update_window_selection()
		utils.set_keymaps()
	end)
end

M.new = function()
	local self = {}
	setmetatable(self, { __index = M })

	local text = NuiText(" Prompt: ", "NeollamaWindowTitle")
	self.input = Input({
		relative = "editor",
		border = {
			style = plugin.config.layout.border.default,
			text = {
				top = text,
				top_align = "center",
			},
		},
		win_options = {
			winhighlight = "Normal:Normal,FloatBorder:NeollamaDefaultBorder",
		},
	}, {
		prompt = plugin.config.layout.input.icon .. " ",
		default_value = nil,
		on_close = function() end,
		on_submit = function(value) -- Inserts user input accordingly while calling the ollama client with the user input
			-- handle save command
			if value == "/s" then
				plugin.layout:hide()

				local user_data = utils.chat_data()

				if user_data.num_chats == user_data.max_chats then
					print("Max sessions reached. Please select a session to overwrite.")
					local m = LayoutHandler.overwrite_menu()
					m.menu:mount()
					return
				end

				local i = M.save_prompt(user_data)
				i.input:mount()
				return
			end

			-- handle config editor command
			if value == "/c" then
				plugin.layout:hide()

				local p = LayoutHandler.param_viewer()
				p.popup:mount()
				LayoutHandler.config_buf = p.popup

				table.insert(LayoutHandler.window_selection, LayoutHandler.config_buf.winid)
				utils.set_keymaps()
				vim.api.nvim_buf_set_name(LayoutHandler.config_buf.bufnr, "neollama-config.lua")

				local buf = LayoutHandler.config_buf.bufnr
				local opts_str = vim.inspect(API.params.opts)
				local extra_opts = vim.inspect(API.extra_opts)

				vim.api.nvim_buf_set_lines(buf, 0, -1, false, utils.param_format(opts_str))
				local current_lines = vim.api.nvim_buf_line_count(buf)
				vim.api.nvim_buf_set_lines(
					buf,
					current_lines + 1,
					current_lines + 1,
					false,
					utils.param_format(extra_opts)
				)

				return
			end

			-- toggle web agent
			if value == "/w" then
				plugin.config.web_agent.enabled = not plugin.config.web_agent.enabled

				LayoutHandler.remount()
				utils.reformat_session(API.params.messages)
				return
			end

			-- check if cursor was set to non plugin window
			local winid = vim.fn.win_getid()
			local is_neollama = false
			for _, v in ipairs(LayoutHandler.window_selection) do
				if v == winid then
					is_neollama = true
				end
			end
			if not is_neollama then
				LayoutHandler.remount()
				utils.reformat_session(API.params.messages)
			end

			-- insert input to chat history
			table.insert(API.params.messages, #API.params.messages + 1, { role = "user", content = value })

			-- check for visual mode including the selection if necessary
			if plugin.mode ~= false then
				API.params.messages[#API.params.messages].mode = true
				API.params.messages[#API.params.messages].content = API.params.messages[#API.params.messages].content
					.. "\n"
					.. plugin.mode
				plugin.mode = false
			end

			-- hide the input and reformat the popup window to include the chat history and current input
			vim.schedule(function()
				LayoutHandler.hide_input()
				LayoutHandler.update_window_selection(true)
				utils.reformat_session(API.params.messages)

				-- initiate empty response string for streamed responses and include empty lines to preserve separation
				if API.params.stream then
					local line_count = vim.api.nvim_buf_line_count(plugin.popup.bufnr)
					vim.api.nvim_buf_set_lines(
						plugin.popup.bufnr,
						line_count + 1,
						line_count + 1,
						false,
						{ _G.NeollamaModel .. ":", "  ", "  " }
					)

					API.constructed_response = ""
				end
			end, 0)

			if plugin.config.web_agent.enabled and plugin.config.web_agent.manual then
				local stop_spinner = utils.spinner(plugin.popup.bufnr, -1)
				web_agent.query_gen(value, function(res)
					web_agent.feedback_loop(value, res, stop_spinner)
					utils.setTimeout(0.5, function()
						ui_update()
						utils.write_log(web_agent.log_info)
					end, function()
						return API.done
					end)
				end)
				return
			end

			-- TODO: create spinner to show progress of web search
			if plugin.config.web_agent.enabled then
				local stop_spinner = utils.spinner(plugin.popup.bufnr, -1)
				web_agent.buffer_agent(value, function(res)
					if res.needs_web_search then
						print("web search needed")
						web_agent.feedback_loop(value, res, stop_spinner)
						utils.setTimeout(0.5, function()
							ui_update()
							utils.write_log(web_agent.log_info)
						end, function()
							return API.done
						end)
						return
					else
						print("web search not needed")
						model_call()
						return
					end
				end)
				return
			end

			model_call()
		end,
	})

	return self
end

M.save_prompt = function(user_data, replacement)
	local self = {}
	setmetatable(self, { __index = M })

	local text = NuiText(" Session Name: ", "NeollamaWindowTitle")
	self.input = Input({
		relative = "editor",
		position = {
			col = "50%",
			row = "50%",
		},
		size = {
			width = 40,
			height = 1,
		},
		border = {
			style = "rounded",
			text = {
				top = text,
				top_align = "center",
			},
		},
		win_options = {
			winhighlight = "Normal:Normal,FloatBorder:NeollamaDefaultBorder",
		},
	}, {
		prompt = "> ",
		default_value = nil,
		on_close = function()
			print("Session save cancelled")
			plugin.layout:show()

			if API.params.messages ~= nil then
				utils.reformat_session(API.params.messages)
				utils.set_keymaps()
			end
			LayoutHandler.update_window_selection()
		end,
		on_submit = function(value)
			if replacement then
				utils.overwrite_chat(replacement, value, API.params)
				for i, session in pairs(user_data.sessions) do
					if session == replacement then
						user_data.sessions[i] = value
						utils.update_data(user_data)
					else
						print("Session " .. value .. " not found.")
					end
				end

				print("Current session saved over " .. replacement .. " as " .. value)
				LayoutHandler.remount()

				utils.set_keymaps()
				LayoutHandler.update_window_selection()
				return
			end

			local co = coroutine.create(function()
				utils.save_chat(value, API.params)

				user_data.num_chats = user_data.num_chats + 1
				table.insert(user_data.sessions, #user_data.sessions + 1, value)
				utils.update_data(user_data)

				print("Session saved as " .. value)
				plugin.layout:show()
				utils.set_keymaps()
				LayoutHandler.update_window_selection()
			end)
			coroutine.resume(co)
		end,
	})
	return self
end

return M
