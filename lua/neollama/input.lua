local Input = require('nui.input')
local utils = require('neollama.utils')

local M = {}

local API
local LayoutHandler
local plugin

M.set_api = function (api)
    API = api
end

M.set_layout_handler = function(handler)
    LayoutHandler = handler
end

M.set_plugin = function (init)
    plugin = init
end

M.remount = function ()
    if API.done == false then
        utils.setTimeout(1, function ()
            local i = M.new()
            plugin.input = i.input
            plugin.input:mount()
            LayoutHandler.window_selection[2] = plugin.input.winid
            if LayoutHandler.menu_shown == true then
                plugin.input:update_layout({
                    position = {
                        col = "30%",
                        row = "80%"
                    }
                })
            end
            API.done = false
            LayoutHandler.window_selection[2] = plugin.input.winid
        end, function() return API.done end)
    else
        local i = M.new()
        plugin.input = i.input
        plugin.input:mount()
        LayoutHandler.window_selection[2] = plugin.input.winid
        if LayoutHandler.menu_shown == true then
            plugin.input:update_layout({
                position = {
                    col = "30%",
                    row = "80%"
                }
            })
        end
        API.done = false
        LayoutHandler.window_selection[2] = plugin.input.winid
    end
end

M.new = function ()
    local self = {}
    setmetatable(self, {__index = M})
    self.input = Input({
        relative = 'editor',
        border = {
            style = "rounded",
            text = {
                top = " Prompt: ",
                top_align = "center",
            },
        },
        win_options = {
            winhighlight = "Normal:Normal,FloatBorder:Normal",
        },
    }, {
            prompt = plugin.config.layout.input.icon .. " ",
            default_value = nil,
            on_close = function()
            end,
            on_submit = function(value) -- Inserts user input accordingly while calling the ollama client with the user input
                if value == "/s" then
                    plugin.layout:hide()

                    local user_data = utils.chat_data()

                    if user_data.num_chats == user_data.max_chats then
                        print('Max sessions reached. Please select a session to overwrite.')
                        local m = LayoutHandler.overwrite_menu()
                        m.menu:mount()
                        return
                    end

                    local i = M.save_prompt(user_data)
                    i.input:mount()
                    return
                end

                if value == "/c" then
                    plugin.layout:hide()

                    local p = LayoutHandler.param_viewer()
                    p.popup:mount()
                    LayoutHandler.config_buf = p.popup

                    table.insert(LayoutHandler.window_selection, LayoutHandler.config_buf.winid)
                    utils.set_keymaps()
                    vim.api.nvim_buf_set_name(LayoutHandler.config_buf.bufnr, 'neollama-config.lua')

                    local buf = LayoutHandler.config_buf.bufnr
                    local opts_str = vim.inspect(API.params.opts)
                    local extra_opts = vim.inspect(API.extra_opts)

                    vim.api.nvim_buf_set_lines(buf, 0, -1, false, utils.param_format(opts_str))
                    local current_lines = vim.api.nvim_buf_line_count(buf)
                    vim.api.nvim_buf_set_lines(buf, current_lines + 1, current_lines + 1, false, utils.param_format(extra_opts))

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
                end

                -- check for visual mode; including the selection if necessary
                table.insert(API.params.messages, #API.params.messages + 1, {role = "user", content = value})
                if plugin.mode ~= false then
                    API.params.messages[#API.params.messages].content = API.params.messages[#API.params.messages].content .. '\n' .. plugin.mode
                    plugin.mode = false
                end

                -- hide the input and reformat the window to include the chat history and current input
                vim.schedule(function ()
                    LayoutHandler.hide_input()
                    LayoutHandler.update_window_selection(true)
                    utils.reformat_session(API.params.messages)

                    -- initiate empty response string for streamed responses and include empty lines to preserve separation
                    if API.params.stream then
                        local line_count = vim.api.nvim_buf_line_count(plugin.popup.bufnr)
                        vim.api.nvim_buf_set_lines(plugin.popup.bufnr, line_count + 1, line_count + 1, false, {_G.NeollamaModel .. ':', "  ", "  "})

                        API.constructed_response = ""
                    end
                end, 0)

                -- check if model is loaded before calling ollama client
                if API.model_loaded then
                    API.ollamaCall()
                else
                    utils.setTimeout(0.5, function ()
                        print('Delayed start: Model loading')
                        API.ollamaCall()
                    end, function() return API.model_loaded end)
                end

                -- check if full response has been generated before showing input
                if API.done then
                    vim.schedule(function ()
                        LayoutHandler.show_input()
                        LayoutHandler.update_window_selection()
                    end, 0)

                    vim.schedule(function ()
                        utils.reformat_session(API.params.messages)
                    end, 0)

                    utils.setTimeout(0.25, function ()
                        vim.api.nvim_set_current_win(plugin.input.winid)
                    end)

                    API.done = false
                else
                    utils.setTimeout(0.5, function ()
                        vim.schedule(function ()
                            LayoutHandler.show_input()
                            LayoutHandler.update_window_selection()
                        end, 0)

                        vim.schedule(function ()
                            utils.reformat_session(API.params.messages)
                        end, 0)

                        utils.setTimeout(0.25, function ()
                            vim.api.nvim_set_current_win(plugin.input.winid)
                        end)

                        API.done = false
                    end, function() return API.done end)
                end

                LayoutHandler.update_window_selection()
                utils.set_keymaps()
            end,
        })

    return self
end

M.save_prompt = function (user_data, replacement)
    local self = {}
    setmetatable(self, {__index = M})
    self.input = Input({
        relative = 'editor',
        position = {
            col = '50%',
            row = '50%'
        },
        size = {
            width = 40,
            height = 1,
        },
        border = {
            style = "rounded",
            text = {
                top = " Session Name: ",
                top_align = "center",
            },
        },
        win_options = {
            winhighlight = "Normal:Normal,FloatBorder:Normal",
        },
    }, {
            prompt = "> ",
            default_value = nil,
            on_close = function()
                print("Session save cancelled")
                plugin.input:show()
                plugin.popup:show()
                if M.menu_shown then
                    plugin.layout:show()
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
                            print('Session ' .. value .. ' not found.')
                        end
                    end

                    print('Current session saved over ' .. replacement ..  ' as ' .. value)
                    plugin.layout:show()

                    utils.set_keymaps()
                    LayoutHandler.update_window_selection()
                    return
                end

                local co = coroutine.create(function ()
                    utils.save_chat(value, API.params)

                    user_data.num_chats = user_data.num_chats + 1
                    table.insert(user_data.sessions, #user_data.sessions + 1, value)
                    utils.update_data(user_data)

                    print('Session saved as ' .. value)
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
