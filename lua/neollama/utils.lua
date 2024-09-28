local M = {}

local plugin
local LayoutHandler
local API

M.set_plugin = function(init)
	plugin = init
end

M.set_layout_handler = function(handler)
	LayoutHandler = handler
end

M.set_api = function(api)
	API = api
end

-- sets delay for function call with optional condition check
---@param timeout integer *delay to execute function*
---@param func fun() *function to be executed after delay*
---@param condition? fun(): boolean|nil *optional condition to check before executing function, each check delayed by `timeout`*
M.setTimeout = function(timeout, func, condition)
	local function conditionCheck()
		if not condition or condition() then
			func()
		else
			vim.defer_fn(conditionCheck, timeout * 1000)
		end
	end
	vim.defer_fn(conditionCheck, timeout * 1000)
end

-- Accesses the selected text from any visual mode and formats it into a multi line string
M.visual_selection = function()
	local current_buf = vim.api.nvim_get_current_buf()
	local mode = vim.api.nvim_get_mode().mode
	local visual = mode == "v" or mode == "V" or mode == "\22"
	if not visual then
		return false
	end

	vim.cmd("normal! gv")

	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local start_line = start_pos[2]
	local start_col = start_pos[3]
	local end_line = end_pos[2]
	local end_col = end_pos[3]

	local lines = vim.api.nvim_buf_get_lines(current_buf, start_line - 1, end_line, false)
	if mode == "v" then
		if start_line == end_line then
			lines[1] = string.sub(lines[1], start_col, end_col)
		else
			lines[1] = string.sub(lines[1], start_col)
			lines[#lines] = string.sub(lines[#lines], 1, end_col)
		end
	elseif mode == "\22" then
		for i, line in ipairs(lines) do
			lines[i] = string.sub(line, start_col, end_col)
		end
	end

	local selected_text = "[[\n"
	for _, line in ipairs(lines) do
		selected_text = selected_text .. line .. "\n"
	end
	selected_text = selected_text .. "]]"

	return selected_text
end

-- Apply and remove keybindings used only from within the plugin --

local group_name = "Neollama"
local augroup = vim.api.nvim_create_augroup(group_name, {})
M.og_keymaps = {}

--[[ Queries for keymaps matching plugins internal keymaps and stores them
in `og_keymaps`before overwriting them with custom internals ]]
M.set_keymaps = function()
	M.internal_keymaps = {
		{
			mode = "n",
			lhs = plugin.config.keymaps.toggle_layout,
			rhs = "<cmd>lua require('neollama.layout').toggle_layout()<CR>",
		},
		{
			mode = "n",
			lhs = plugin.config.keymaps.window_next,
			rhs = "<cmd>lua require('neollama.layout').window_next()<CR>",
		},
		{
			mode = "n",
			lhs = plugin.config.keymaps.window_prev,
			rhs = "<cmd>lua require('neollama.layout').window_prev()<CR>",
		},
		{
			mode = "n",
			lhs = plugin.config.keymaps.change_config,
			rhs = "<cmd>lua require('neollama.utils').change_config(vim.api.nvim_get_current_buf())<CR>",
		},
		{
			mode = "n",
			lhs = "<esc>",
			rhs = "<cmd>lua require('neollama.utils').close_map()<CR>",
		},
	}
	for _, keymap in ipairs(M.internal_keymaps) do
		local current_keymap = vim.api.nvim_get_keymap(keymap.mode)
		for _, map in ipairs(current_keymap) do
			if map.lhs == keymap.lhs then
				M.og_keymaps[keymap.mode .. keymap.lhs] = map
				break
			end
		end
		if
			keymap.rhs == "<cmd>lua require('neollama.layout').window_next()<CR>"
			or keymap.rhs == "<cmd>lua require('neollama.layout').window_prev()<CR>"
		then
			vim.api.nvim_set_keymap(
				keymap.mode,
				keymap.lhs,
				keymap.rhs,
				{ noremap = true, silent = true, nowait = true }
			)
			goto continue
		end
		vim.api.nvim_set_keymap(keymap.mode, keymap.lhs, keymap.rhs, { noremap = true, silent = true })
		::continue::
	end
end

-- Restores original keymaps if present, removes otherwise
M.reset_keymap = function()
	if #M.og_keymaps == 0 then
		for _, keymap in ipairs(M.internal_keymaps) do
			pcall(vim.keymap.del, keymap.mode, keymap.lhs)
		end
	else
		for key, map in pairs(M.og_keymaps) do
			local mode = key:sub(1, 1)
			local lhs = key:sub(2)
			vim.api.nvim_set_keymap(
				mode,
				lhs,
				map.rhs,
				{ noremap = map.noremap == 1, silent = map.silent == 1, expr = map.expr == 1, nowait = map.nowait == 1 }
			)
		end
		M.og_keymaps = {}
	end
end

-- Checks if current window belongs to Neollama and sets keymaps accordingly
M.check_window = function()
	local winid = vim.fn.win_getid()
	local is_neollama = false

	for index, value in ipairs(LayoutHandler.window_selection) do
		if value == winid then
			is_neollama = true
			window_index = index
			break
		end
	end

	if not is_neollama then
		plugin.layout:hide()

		M.reset_keymap()
		plugin.active_session_shown = false
		return
	else
		M.set_keymaps()
	end
end

M.close_map = function()
	if plugin.layout then
		plugin.layout:unmount()
	end
	plugin.active_session_shown = false
	plugin.active_session = false
end

-- MODEL CONFIG HANDLING --

-- Format the recieved table string back to a lua table seperated by lines
M.param_format = function(opts)
	local t = {}
	for line in string.gmatch(opts, "([^" .. "\n" .. "]+)") do
		table.insert(t, line)
	end
	table.insert(t, "")
	return t
end

--[[ Takes the formatted tables from the config buffer and assigns their new values to the model options
before remounting the current session and closing the config editor ]]
M.change_config = function(current_buffer)
	if current_buffer ~= LayoutHandler.config_buf.bufnr then
		return
	end

	local new_opts = M.read_params()
	API.params.opts = new_opts[1]
	API.extra_opts = new_opts[2]
	API.get_opts()

	LayoutHandler.config_buf:unmount()
	plugin.layout:show()

	LayoutHandler.update_window_selection()
	M.set_keymaps()
end

-- Reads the config buffer and transforms to a string before loading and returning the strings as seperate table values
M.read_params = function()
	local content = vim.api.nvim_buf_get_lines(LayoutHandler.config_buf.bufnr, 0, -1, false)
	local str = table.concat(content, "\n")

	local t = {}
	local current_table = ""
	local depth = 0

	for line in str:gmatch("[^\r\n]+") do
		if line:match("{") then
			if depth == 0 then
				current_table = ""
			end
			depth = depth + 1
		end

		if depth > 0 then
			current_table = current_table .. line .. "\n"
		end

		if line:match("}") then
			depth = depth - 1
			if depth == 0 then
				table.insert(t, current_table)
			end
		end
	end

	t[1] = load("return " .. t[1])()
	t[2] = load("return " .. t[2])()

	return t
end

--  CHAT/USER DATA --

local data_dir = vim.env.HOME .. "/.local/share/nvim/neollama"

-- Checks if data directory and file structure exists before ensuring user_data file is populated
M.data_dir_check = function()
	if not vim.loop.fs_stat(data_dir) then
		print("No data directory could be located. Creating directory at " .. data_dir)
		vim.loop.fs_mkdir(data_dir, 511)
	end

	local function check_file()
		local files = { data_dir .. "/chats.lua", data_dir .. "/user_data.json" }
		local files_needed = false

		for _, file in ipairs(files) do
			if not vim.loop.fs_stat(file) then
				print("No chat file could be located. Creating file at " .. file)
				files_needed = true
				local f = io.open(file, "w")
				if f then
					f:close()
				end
			end
		end

		return not files_needed
	end
	-- check_file()

	local file_creation_attempt = 1
	local max_attempts = 6
	local function data_check()
		if not check_file() then
			file_creation_attempt = file_creation_attempt + 1
			if file_creation_attempt > max_attempts then
				print("Neollama: Function timed out waiting for data files to be created. Please try again")
				return
			else
				M.setTimeout(0.25, data_check)
				return
			end
		end

		local user_data = io.open(data_dir .. "/user_data.json", "r")
		local user_content
		if user_data then
			user_content = user_data:read("*all")
			user_data:close()
		end

		if not user_content then
			print(
				"The user data file was either not created or could not be read. Please try again.\nIf the issue persists check the following files:\n"
					.. data_dir
					.. "/chats.lua\n"
					.. data_dir
					.. "/user_data.json"
			)
		end
		if not user_content:find("}") then
			local default_config = {
				max_chats = plugin.config.max_chats,
				num_chats = 0,
				sessions = {},
			}

			user_data = io.open(data_dir .. "/user_data.json", "w")
			if user_data then
				user_data:write(vim.json.encode(default_config))
				user_data:close()
			end
		end
	end

	data_check()
end

-- Writes the current session to the chat file followed by an empty string
M.save_chat = function(name, value)
	local chat_file = data_dir .. "/chats.lua"
	local file = io.open(chat_file, "a+")
	if file then
		file:write("local " .. name .. " = " .. tostring(vim.inspect(value)))
		file:write("")
		file:close()
	else
		print("Chat file not found")
	end
end

-- Reads chat file into string and queries based on the passed in session name
M.load_chat = function(name)
	local chat_file = data_dir .. "/chats.lua"
	local file = io.open(chat_file, "r")
	if not file then
		print("Chat file not found")
		return nil
	end

	local content = file:read("*all")
	file:close()

	local match = content:match("local%s+" .. name .. "%s*=%s*(%b{})")

	return load("return " .. match)()
end

-- Find-and-replace function for queries on the chats file
M.overwrite_chat = function(target, repl_name, repl)
	local chat_file = data_dir .. "/chats.lua"
	local file = io.open(chat_file, "r")
	if not file then
		print("Chat file not found")
		return nil
	end

	local content = file:read("*all")
	file:close()
	local updated_content = content:gsub(
		"local%s+" .. target .. "%s*=%s*(%b{})",
		"local " .. repl_name .. " = " .. tostring(vim.inspect(repl))
	)

	local replacement = io.open(chat_file, "w")
	if not replacement then
		print("Chat file not found")
		return nil
	end
	replacement:write(updated_content)
	replacement:close()
end

-- Loads the undefined table in the user_data file as table to be defined and modified
M.chat_data = function()
	local user_file = data_dir .. "/user_data.json"
	local file = io.open(user_file, "r")
	if not file then
		print("User data file not found")
		return nil
	end

	local content = file:read("*all")
	file:close()

	local data = load("return " .. vim.inspect(vim.json.decode(content)))()

	return data
end

-- Reloading the table and inserting it back into the file after modifications have been made
M.update_data = function(data)
	local user_file = data_dir .. "/user_data.json"
	local file = io.open(user_file, "w+")
	if not file then
		print("User data file not found")
		return nil
	end

	local content = vim.json.encode(data)
	file:write(content)
	file:close()
end

-- TEXT/LAYOUT MANIPULATION --

-- Custom line wrqp function to respect virtual text
M.line_wrap = function(str, width)
	local t = {}
	local current_line = ""
	for word in str:gmatch("%S+") do
		if vim.fn.strdisplaywidth(current_line .. " " .. word) > width then
			table.insert(t, current_line)
			current_line = word
		else
			current_line = current_line == "" and word or current_line .. " " .. word
		end
	end
	if current_line ~= "" then
		table.insert(t, current_line)
	end
	return t
end

M.session_resize = function()
	if vim.o.columns < 120 or vim.o.lines < 35 then
		if plugin.active_session and plugin.active_session_shown then
			plugin.layout:update({
				position = "50%",
				size = {
					width = "95%",
					height = "95%",
				},
			})
		end

		LayoutHandler.resized = true
	else
		if plugin.active_session and plugin.active_session_shown then
			plugin.layout:update({
				position = "50%",
				size = {
					width = "70%",
					height = "80%",
				},
			})
		end

		LayoutHandler.resized = false
	end
end

-- Saves original cursor highlight group for reverting back after cursor is reshown
M.og_cursor = nil
M.og_cursor_hl = nil
M.save_cursor = function()
	if M.og_cursor_hl == nil then
		local t = {}
		local hl = vim.api.nvim_exec("highlight Cursor", true)
		for word in string.gmatch(hl, "%S+") do
			table.insert(t, word)
		end
		local hl_string = t[3] .. " " .. t[4] .. " blend=0"
		if hl_string then
			M.og_cursor_hl = hl_string
		else
			M.og_cursor_hl = ""
		end
		M.og_cursor = vim.o.guicursor
	end
end

-- Hides cursor when current window ID contains the `NeollamaLayoutMenu` window variable
M.hide_cursor = function()
	M.save_cursor()

	local winID = vim.api.nvim_get_current_win()

	local is_menu = false
	local status, res = pcall(vim.api.nvim_win_get_var, winID, "NeollamaLayoutMenu")
	if status then
		is_menu = res
	end

	if is_menu then
		vim.cmd("set guicursor=a:Cursor/lCursor")
		vim.cmd("highlight Cursor blend=100")
	else
		if M.og_cursor_hl and M.og_cursor_hl ~= "" then
			vim.cmd("highlight Cursor " .. M.og_cursor_hl)
		end
		vim.cmd("set guicursor=" .. M.og_cursor)
	end
end

-- Reformat loaded sessions to popup window
M.reformat_session = function(messages)
	vim.api.nvim_buf_set_lines(plugin.popup.bufnr, 0, -1, false, {}) -- clear current popup window

	for _, message in ipairs(messages) do
		if message.role ~= "user" and message.role ~= "system" and message.role ~= "tool" then
			LayoutHandler.insert_response(plugin.popup, message)
		elseif message.role == "user" then
			LayoutHandler.insert_input(plugin.popup, message)
		end
	end

	vim.cmd("normal! G")
end

-- HIGHLIGHTING --

M.set_user_heading = function(buf, buf_lines)
	for line_count, line in ipairs(buf_lines) do
		local start = 1
		while true do
			local start_col, end_col = string.find(line, "User:", start)
			if start_col then
				vim.api.nvim_buf_add_highlight(buf, -1, "NeollamaUserHeader", line_count - 1, start_col - 1, end_col)
				start = end_col + 1
			else
				break
			end
		end
	end
end

M.set_model_heading = function(buf, model, buf_lines)
	model = model:gsub("([%%%.%+%-])", "%%%1")
	for line_count, line in ipairs(buf_lines) do
		local start = 1
		while true do
			local start_col, end_col = string.find(line, model .. ":", start)
			if start_col then
				vim.api.nvim_buf_add_highlight(buf, -1, "NeollamaModelHeader", line_count - 1, start_col - 1, end_col)
				start = end_col + 1
			else
				break
			end
		end
	end
end

return M
