local M = {}

M.utils = require('neollama.utils')
M.Layout = require('neollama.layout')
M.Input = require('neollama.input')
M.api = require('neollama.api')
M.mediator = require('neollama.mediator')

M.mediator.setup(M.api, M.Layout, M.Input, M.utils, M)

-- Initial model loading for quickest response time in default session
M.api.list_models()
M.api.get_opts()

-- Ensure session variables are set to default upon loading
M.active_session = false
M.active_session_shown = false

M.plugin_dir = debug.getinfo(1, 'S').source:sub(2):match("(.*[/\\])")

M.config = {
    autoscroll = true,
    hide_cursor = true,
    params = {
        model = 'llama3',
        stream = false,
        default_options = M.api.default_options,
        extra_opta = M.api.extra_opts
    },
    layout = {
        border = 'rounded',
        size = {
            width = '70%',
            height = '80%'
        },
        position = '50%',
        title_hl = "String",
        border_hl = "FloatBorder",
        popup = {
            header_style = "underline",
            user_hl = "Normal",
            model_hl = "Normal",
            virtual_text = {"╒", "│", "╘"}
        },
        input = {
            icon = ">",
            text_hl = "Comment",
        },
        model_picker = {
            icon = "",
            hl = "Keyword"
        },
        session_picker = {
            icon = "",
            hl = "Keyword"
        }
    },
    keymaps = {
        toggle_layout = '<leader>ct',
        window_next = '}',
        window_prev = '{',
        change_config = '<leader>cs'
    }
}

M.setup = function (user_config)
    local config = vim.tbl_deep_extend('force', M.config, user_config)
    M.api.default_options = config.params.default_options
    M.api.extra_opts = config.params.extra_opts
    M.config = config
end

M.initialize = function ()
    -- Opens session if one is available; remounting windows in their previous state
    if M.active_session and not M.active_session_shown then
        M.mode = M.utils.visual_selection()

        M.layout:show()
        if vim.api.nvim_buf_line_count(M.popup.bufnr) <= 1 and M.api.params.messages ~= nil then
            M.utils.reformat_session(M.api.params.messages)
        end

        M.utils.set_keymaps()
        M.active_session_shown = true
        M.Layout.update_window_selection()

        return
    elseif M.active_session_shown and M.active_session then
        print('Unable to start new session with active running session')
        return
    end

    -- Capture current vim mode
    M.mode = M.utils.visual_selection()

    -- Model list is updated each time session is created to ensure most up to date list, same is done with opts
    M.api.list_models()
    M.api.get_opts()

    -- Load model for quickest response time
    M.api.load_model(_G.NeollamaModel)

    -- Initialize plugin windows and set internal mappings --
    vim.schedule(function()
        local p = M.Layout.popup()
        M.popup = p.popup

        local i = M.Input.new()
        M.input = i.input

        -- Initialize menu pickers for session layout
        M.model_picker = M.Layout.model_picker().menu
        M.session_picker = M.Layout.session_picker().menu

        --Insert initial window IDs for navigation
        M.Layout.update_window_selection()

        -- Check if local model list is available before initializing layout window
        if M.api.model_list == nil then

            M.utils.setTimeout(1, function ()

                print('Delayed start: Model List')
                local l = M.Layout.main_layout(M.popup, M.input, M.model_picker, M.session_picker)

                M.layout = l.layout
                M.layout:mount()

            end, function() return M.api.model_list end)

        else
            local l = M.Layout.main_layout(M.popup, M.input, M.model_picker, M.session_picker)
            M.layout = l.layout

            M.layout:mount()
        end

        M.utils.set_keymaps()
        M.active_session = true
        M.active_session_shown = true

    end)

    vim.api.nvim_command("autocmd WinEnter * lua require('neollama.utils').check_window()")
    vim.api.nvim_command("autocmd VimResized * lua require('neollama.layout').session_resize()")
    if M.config.hide_cursor then
        vim.api.nvim_command("autocmd BufEnter * lua require('neollama.utils').hide_cursor()")
    end

end

return M
