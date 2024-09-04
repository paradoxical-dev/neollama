require('lilcumstain.neollama.opts')
local Popup = require('nui.popup')
local Layout = require('nui.layout')
local Menu = require('nui.menu')
local event = require('nui.utils.autocmd').event

local M = {}

local API
local input
local plugin
local utils

M.set_api = function (api)
    API = api
end
M.set_plugin = function (init)
    plugin = init
end
M.set_input = function (i)
    input = i
end
M.set_utils = function (util)
    utils = util
end

-- LAYOUT TOGGLING --

--[[ Logic for toggeling the layout module checks; for whether the module
is shown or mounted before adjusting other window layouts ]]
M.menu_shown = true
M.resized = false
M.toggle_layout = function ()
    local resized_dimensions
    if M.resized then
        resized_dimensions = '95%'
    end
    if not M.menu_shown then
        plugin.layout:update({
            position = "50%",
            size = {
                width = resized_dimensions or "70%",
                height = resized_dimensions or "80%"
            }
        },
            Layout.Box({
                Layout.Box({
                    Layout.Box(plugin.popup, {grow = 2}),
                    Layout.Box(plugin.input, {size = 1}),
                }, {dir = 'col', size = '80%'}),
                Layout.Box({
                    Layout.Box(plugin.model_picker, {size = '40%'}),
                    Layout.Box(plugin.session_picker, {grow = 2}),
                }, {dir = 'col', size = '20%'})
            }, {dir = 'row'}))

        M.menu_shown = true
        M.update_window_selection()
        return
    else
        plugin.layout:update({
            position = "50%",
            size = {
                width = resized_dimensions or "70%",
                height = resized_dimensions or "80%"
            }
        },
            Layout.Box({
                Layout.Box({
                    Layout.Box(plugin.popup, {grow = 2}),
                    Layout.Box(plugin.input, {size = 1}),
                }, {dir = 'col', grow = 2}),
            }))

        M.menu_shown = false
        M.update_window_selection()
        return
    end
end

-- hide the input during response generation
M.hide_input = function ()
    plugin.popup = M.popup().popup

    if M.menu_shown then
        plugin.model_picker = M.model_picker().menu
        plugin.session_picker = M.session_picker().menu

        plugin.layout:update({
            position = "50%",
            size = {
                width = "70%",
                height = "80%"
            }
        },
            Layout.Box({
                Layout.Box({
                    Layout.Box(plugin.popup, {grow = 2}),
                }, {dir = 'col', size = '80%'}),
                Layout.Box({
                    Layout.Box(plugin.model_picker, {size = '40%'}),
                    Layout.Box(plugin.session_picker, {grow = 2}),
                }, {dir = 'col', size = '20%'})
            }, {dir = 'row'}))

        M.update_window_selection()
        return
    else
        plugin.layout:update({
            position = "50%",
            size = {
                width = "70%",
                height = "80%"
            }
        },
            Layout.Box({
                Layout.Box({
                    Layout.Box(plugin.popup, {grow = 2}),
                }, {dir = 'col', grow = 2}),
            }))

        M.update_window_selection()
        return
    end
end

-- show the input only after the response has been generated
M.show_input = function ()
    plugin.popup = M.popup().popup
    plugin.input = input.new().input

    if M.menu_shown then
        plugin.model_picker = M.model_picker().menu
        plugin.session_picker = M.session_picker().menu
        plugin.layout:update(
            Layout.Box({
                Layout.Box({
                    Layout.Box(plugin.popup, {grow = 2}),
                    Layout.Box(plugin.input, {size = 1}),
                }, {dir = 'col', size = '80%'}),
                Layout.Box({
                    Layout.Box(plugin.model_picker, {size = '40%'}),
                    Layout.Box(plugin.session_picker, {grow = 2}),
                }, {dir = 'col', size = '20%'})
            }, {dir = 'row'})
        )

        M.update_window_selection()
    else
        plugin.layout:update(
            Layout.Box({
                Layout.Box({
                    Layout.Box(plugin.popup, {grow = 2}),
                    Layout.Box(plugin.input, {size = 1}),
                }, {dir = 'col', grow = 2}),
            }))

        M.update_window_selection()
    end
end

-- WINDOW NAVIGATION --

M.window_selection = {}
M.current_index = 2

--[[ Delay window slection update until current working process has finished
this is to avoid any overlapping process to interrupt the update process ]]
M.update_window_selection = vim.schedule_wrap(function (input_hidden)
    M.window_selection = {}
    table.insert(M.window_selection, plugin.popup.winid)
    if input_hidden then
        if M.menu_shown then
            table.insert(M.window_selection, plugin.model_picker.winid)
            table.insert(M.window_selection, plugin.session_picker.winid)
        end
    else
        table.insert(M.window_selection, plugin.input.winid)
        if M.menu_shown then
            table.insert(M.window_selection, plugin.model_picker.winid)
            table.insert(M.window_selection, plugin.session_picker.winid)
        end
    end
end)

--[[ Track the current index relative to window_selection
navigate to the next or previous respectively ]]
M.window_next = function ()
    if #M.window_selection == 0 then return end

    M.current_index = M.current_index + 1
    if M.current_index > #M.window_selection then
        M.current_index = 1
    end

    local ok, _ = pcall(vim.api.nvim_set_current_win, M.window_selection[M.current_index])
    if not ok then
        utils.setTimeout(0.05, function ()
            print("she wasn't readyyy")
        end, function() local res, _ = pcall(vim.api.nvim_set_current_win, M.window_selection[M.current_index]) return res end)
    end
end

M.window_prev = function ()
    if #M.window_selection == 0 then return end

    M.current_index = M.current_index - 1
    if M.current_index < 1 then
        M.current_index = #M.window_selection
    end

    local ok, _ = pcall(vim.api.nvim_set_current_win, M.window_selection[M.current_index])
    if not ok then
        utils.setTimeout(0.05, function ()
            print("she wasn't readyyy")
        end, function() local res, _ = pcall(vim.api.nvim_set_current_win, M.window_selection[M.current_index]) return res end)
    end
end

-- TEXT INSERTION --

M.insert_vtext = function (bufnr, linenr, text, hl_group, namespace)
    vim.api.nvim_buf_set_extmark(bufnr, vim.api.nvim_create_namespace(namespace), linenr - 1, 0, {
        virt_text = {{text, hl_group}},
        virt_text_pos = 'overlay',
    })
end


--[[ Append user input to popup buffer. At the top for
initial input and seperated by exmpty line for any following input ]]
M.insert_input = function(popup,value)
    local buf = popup.bufnr
    local current_lines = vim.api.nvim_buf_line_count(buf)

    local wrapped_lines = {"User: "}
    local t = utils.line_wrap(value, popup._.size.width - 2)
    for _, line in ipairs(t) do
        table.insert(wrapped_lines, line)
    end
    table.insert(wrapped_lines, '')

    if current_lines <= 1 then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, wrapped_lines)
    else
        vim.api.nvim_buf_set_lines(buf, current_lines + 1, -1, false, wrapped_lines)
    end
end

--[[ Awaits for `done` variable to be updated before updating
popup buffer with the job response. ]]
M.insert_response = function(popup,response)
    local res = API.response_split(response)
    local buf = popup.bufnr
    local current_lines = vim.api.nvim_buf_line_count(buf)

    vim.api.nvim_buf_set_lines(buf, current_lines + 1, current_lines + 1, false, res)
    for i=current_lines + 2, vim.api.nvim_buf_line_count(buf) - 1 do
        if i == current_lines + 2 then
            M.insert_vtext(buf, i, "╒", "Keyword", "NeollamaChatVirtualText")
        elseif i == vim.api.nvim_buf_line_count(buf) - 1 then
            M.insert_vtext(buf, i, "╘", "Keyword", "NeollamaChatVirtualText")
        else
            M.insert_vtext(buf, i, "│", "Keyword", "NeollamaChatVirtualText")
        end
    end
end

-- WINDOW CREATION --

-- Creates a new instance of popup buffer with predefined options
M.popup = function ()
    local self = {}
    setmetatable(self, {__index = M})
    self.popup = Popup({
        relative = 'editor',
        enter = true,
        focusable = true,
        -- ns_id = 'neollama',
        -- zindex = 1,
        border = {
            style = 'rounded',
            text = {
                top = ' ' .. _G.model .. ' ',
                top_align = 'center',
            },
            padding = {1, 1},
        },
        buf_options = {
            filetype = 'markdown',
            modifiable = true,
            readonly = false,
        },
    })
    return self
end

-- Overwrite selection menu; passes selection value to save inoput for new name selection
M.overwrite_menu = function ()
    local self = {}
    setmetatable(self, {__index = M})
    local user_data = utils.chat_data()
    local function get_opts()
        local t = {}
        for _, session in ipairs(user_data.sessions) do
            table.insert(t, #t + 1, Menu.item(session))
        end
        return t
    end
    local opts = get_opts()
    self.menu = Menu({
        relative = 'editor',
        border = {
            style = 'rounded',
            text = {
                top = "{ Model to Overwrite }",
                top_align = 'center',
            },
            padding = {1,0}
        },
        position = '50%',
        size = {
            width = 35,
            height = 5,
        },
    }, {
            lines = opts,
            keymap = {
                focus_next = { "j", "<Down>" },
                focus_prev = { "k", "<Up>" },
                close = { "<Esc>", "<C-c>" },
                submit = { "<CR>" }
            },
            on_close = function ()
                print('Overwrite cancelled')
                plugin.input:show()
                plugin.popup:show()
                if M.menu_shown then
                    plugin.layout:show()
                end
                utils.set_keymaps()
                M.update_window_selection()
            end,
            on_submit = function (item)
                input.save_prompt(user_data, item.text).input:mount()
            end
        })
    return self
end

--[[ Defines the session window for use in the settings layout
used for selecting and loading previously saved models ]]
M.session_picker = function ()
    local self = {}
    setmetatable(self, {__index = M})
    local user_data = utils.chat_data()

    if user_data == nil then
        utils.setTimeout(0.5, function ()
            print('Delayed start: user data')
            user_data = user_data
        end, function() return user_data end)
    end

    local selections = {}
    local function get_opts()
        local t = {}
        for _, session in ipairs(user_data.sessions) do
            table.insert(selections, session)
            table.insert(t, #t + 1, Menu.item(' ' .. session))
        end
        return t
    end

    local opts = get_opts()
    self.menu = Menu({
        relative = 'editor',
        enter = false,
        border = {
            style = 'rounded',
            text = {
                top = "   Saved Sessions ",
                top_align = 'center',
            },
            padding = {1,1}
        },
    }, {
            lines = opts,
            keymap = {
                focus_next = { "j", "<Down>" },
                focus_prev = { "k", "<Up>" },
                close = {},
                submit = { "<CR>" }
            },
            on_change = function(item, menu) -- Used to truncate menu items based on length
                local nodes = menu.tree.nodes.by_id

                local menu_width = math.floor(plugin.layout._.float.container_info.size.width * 0.2)
                for _, node in pairs(nodes) do
                    if vim.fn.strdisplaywidth(node.text) >= menu_width then
                        local short_str = node.text:gsub(1, -3)
                        node.text = short_str .. '...'
                    end
                end

                menu._tree:render()
            end,
            on_submit = function (item)
                local ok, _ = pcall(vim.api.nvim_set_current_win, M.window_selection[2])
                if not ok then
                    plugin.initialize()
                    M.update_window_selection()
                end

                vim.schedule(function()
                    local new_session = item.text:gsub("^ ", "")
                    if item.text:match('...') then
                        for _, value in ipairs(selections) do
                            if value:match(new_session:gsub(1, -3)) then
                                new_session = value
                                break
                            end
                        end
                    end

                    print("Loading  session: " .. new_session)
                    local session_config = utils.load_chat(new_session)

                    API.params.messages = session_config.messages
                    API.params.stream = session_config.stream
                    API.params.opts = session_config.opts
                    API.params.model = session_config.model
                    _G.model = session_config.model

                    utils.reformat_session(session_config.messages)
                end, 0)

                M.remount()
                utils.set_keymaps()
            end
        })
    return self
end

-- Menu used to change model in current session
M.model_picker = function ()
    local self = {}
    setmetatable(self, {__index = M})

    local selections = {}   --Used to store full model names for selection of shortened names
    local function prep(models)
        local t = {}
        for _, model in ipairs(models) do
            table.insert(selections, model)
            table.insert(t, #t + 1, Menu.item(model))
            table.insert(t, #t + 1, Menu.item(' '))
        end
        return t
    end

    local model_list
    if API.model_list == nil then
        print('Delayed start: Model list')
        utils.setTimeout(1, function ()
            model_list = prep(API.model_list)
        end, function() return API.model_list end)
    else
        model_list = prep(API.model_list)
    end

    self.menu = Menu({
        relative = 'editor',
        enter = false,
        border = {
            style = 'rounded',
            text = {
                top = "   Model ",
                top_align = 'center',
            },
            padding = {1,1}
        },
    }, {
            lines = model_list,
            keymap = {
                focus_next = { "j", "<Down>" },
                focus_prev = { "k", "<Up>" },
                close = {},
                submit = { "<CR>" }
            },

            should_skip_item = function(item)
                if item.text == ' ' then
                    return true
                else
                    return false
                end
            end,

            on_change = function(item, menu)
                local nodes = menu.tree.nodes.by_id
                for _, node in pairs(nodes) do
                    node.text = node.text:gsub("^  ", "")
                    menu._tree:render()
                end
                item.text = "  " .. item.text

                local menu_width = math.floor(plugin.layout._.float.container_info.size.width * 0.2)
                if vim.fn.strdisplaywidth(item.text) >= menu_width then
                    local short_str = item.text:gsub(1, -3)
                    item.text = short_str .. '...'
                end

                menu._tree:render()
            end,

            on_submit = function (item)
                vim.schedule(function()
                    if item.text:match('...') then
                        local raw_name = item.text:gsub("^  ", "")
                        for _, value in ipairs(selections) do
                            if value:match(raw_name:gsub(1, -3)) then
                                item.text = value
                            end
                        end
                    end

                    _G.model = item.text:gsub("^  ", "")
                    API.params.model = _G.model
                    API.reset_opts()

                    API.model_loaded = false
                    API.model_opts = nil
                    API.load_model(_G.model)
                    API.get_opts()

                    M.remount()
                    utils.set_keymaps()
                end, 0)
            end
        })
    return self
end

-- Popup to display current options in a modifiable lua table
M.param_viewer = function ()
    local self = {}
    setmetatable(self, {__index = M})
    self.popup = Popup({
        relative = 'editor',
        enter = true,
        focusable = true,
        ns_id = 'neollama',
        zindex = 1,
        border = {
            style = 'rounded',
            text = {
                top = ' ' .. 'Config Editor' .. ' ',
                top_align = 'center',
            },
            padding = {1, 1},
        },
        position = '50%',
        size = {
            width = '50%',
            height = '50%'
        },
        buf_options = {
            buftype = '',
            filetype = 'lua',
            modifiable = true,
            readonly = false,
        },
    })
    return self
end

M.main_layout = function(p, i, menu1, menu2)
    local self = {}
    setmetatable(self, {__index = M})
    if menu1 and menu2 then
        self.layout = Layout({
            relative = 'editor',
            position = '50%',
            size = {
                width = '70%',
                height = '80%'
            },
        },
            Layout.Box({
                Layout.Box({
                    Layout.Box(p, {grow = 2}),
                    Layout.Box(i, {size = 1}),
                }, {dir = 'col', size = '80%'}),
                Layout.Box({
                    Layout.Box(menu1, {size = '40%'}),
                    Layout.Box(menu2, {grow = 2}),
                }, {dir = 'col', size = '20%'})
            }, {dir = 'row'})
        )

        -- Add winvar to menus to hide cursor when within them
        if menu1.winid == nil or menu2.winid == nil then
            utils.setTimeout(0.25, function ()
                vim.api.nvim_win_set_var(menu1.winid, "NeollamaLayoutMenu", true)
                vim.api.nvim_win_set_var(menu2.winid, "NeollamaLayoutMenu", true)
            end, function() return menu1.winid end)
        else
            vim.api.nvim_win_set_var(menu1.winid, "NeollamaLayoutMenu", true)
            vim.api.nvim_win_set_var(menu2.winid, "NeollamaLayoutMenu", true)
        end

        return self
    else
        self.layout = Layout({
            relative = 'editor',
            position = '50%',
            size = {
                width = '70%',
                height = '80%'
            },
        },
            Layout.Box({
                Layout.Box({
                    Layout.Box(p, {grow = 2}),
                    Layout.Box(i, {size = 1}),
                }, {dir = 'col', size = '80%'}),
            }, {dir = 'row'})
        )
        return self
    end
end

-- Asynchronusly reload the windows used wthin the layout module before mounting
M.remount = function ()
    local co = coroutine.create(function ()
        plugin.model_picker = M.model_picker().menu
        plugin.session_picker = M.session_picker().menu
        plugin.popup = M.popup().popup
        plugin.input = input.new().input

        local l = M.main_layout(plugin.popup, plugin.input, plugin.model_picker, plugin.session_picker)
        plugin.layout = l.layout
        plugin.layout:mount()

        M.update_window_selection()

        if vim.api.nvim_buf_line_count(plugin.popup.bufnr) <= 1 and API.params.messages ~= nil then
            utils.reformat_session(API.params.messages)
        end
    end)
    coroutine.resume(co)
end

return M