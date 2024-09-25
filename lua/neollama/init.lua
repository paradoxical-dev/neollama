local M = {}

M.utils = require('neollama.utils')
M.Layout = require('neollama.layout')
M.Input = require('neollama.input')
M.api = require('neollama.api')
M.mediator = require('neollama.mediator')
M.mediator.setup(M.api, M.Layout, M.Input, M.utils, M)

M.config = {
    autoscroll = true,
    hide_cursor = true,
    max_chats = 10,
    hide_pasted_text = true,
    params = {
        model = 'llama3:latest',
        stream = false,
        default_options = M.api.default_options,
        extra_opts = M.api.extra_opts
    },
    layout = {
        border = {
            default = "rounded",
        },
        size = {
            width = '70%',
            height = '80%'
        },
        position = '50%',
        hl = {
            title = {link = "Comment"},
            default_border = {link = "FloatBorder"},
        },
        popup = {
            hl = {
                user_header = {link = "Keyword"},
                model_header = {link = "Function"},
                virtual_text = {link = "Conditional"},
            },
            virtual_text = {"╒", "│", "╘"},
        },
        input = {
            icon = ">",
            text_hl = "Comment",
        },
        model_picker = {
            icon = "",
            hl = {link = "Keyword"}
        },
        session_picker = {
            default_icon = "󰄰 ",
            current_icon = "󰄴 ",
            current_hl = {link = "Keyword"},
            default_hl = {link = "Comment"}
        }
    },
    keymaps = {
        toggle_layout = '<leader>ct',
        window_next = '}',
        window_prev = '{',
        change_config = '<leader>cs'
    }
}

_G.NeollamaModel = M.config.params.model
M.api.params = {
    model = _G.NeollamaModel,
    messages = {},
    stream = M.config.params.stream,
    opts = M.config.params.default_options
}

M.setup = function (user_config)
    local config = vim.tbl_deep_extend('force', M.config, user_config)
    M.api.default_options = config.params.default_options
    M.api.extra_opts = config.params.extra_opts
    M.config = config

    _G.NeollamaModel = config.params.model

    vim.api.nvim_set_hl(0, "NeollamaUserHeader", config.layout.popup.hl.user_header)
    vim.api.nvim_set_hl(0, "NeollamaModelHeader", config.layout.popup.hl.model_header)
    vim.api.nvim_set_hl(0, "NeollamaWindowTitle", config.layout.hl.title)
    vim.api.nvim_set_hl(0, "NeollamaDefaultBorder", config.layout.hl.default_border)
    vim.api.nvim_set_hl(0, "NeollamaChatVirtualText", config.layout.popup.hl.virtual_text)
    vim.api.nvim_set_hl(0, "NeollamaSessionMenuDefault", config.layout.session_picker.default_hl)
    vim.api.nvim_set_hl(0, "NeollamaSessionMenuCurrent", config.layout.session_picker.current_hl)
    vim.api.nvim_set_hl(0, "NeollamaModelMenu", config.layout.model_picker.hl)
end

-- Run the data files through the checker upon initialization
M.utils.data_dir_check()

-- Ensure session variables are set to default upon loading
M.active_session = false
M.active_session_shown = false

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

    -- Initialize empty chat history
    M.api.params = {
        model = M.config.params.model,
        messages = {},
        stream = M.config.params.stream,
        opts = M.config.params.default_options
    }

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

        -- Check if local model list is available before initializing layout window
        if M.api.model_list == nil then

            M.utils.setTimeout(0.25, function ()

                print('Delayed start: Model List')

                -- Initialize menu pickers for session layout
                M.model_picker = M.Layout.model_picker().menu
                M.session_picker = M.Layout.session_picker().menu
                local l = M.Layout.main_layout(M.popup, M.input, M.model_picker, M.session_picker)

                M.layout = l.layout
                M.layout:mount()

                --Insert initial window IDs for navigation
                M.Layout.update_window_selection()
            end, function() return M.api.model_list end)

        else

            -- Initialize menu pickers for session layout
            M.model_picker = M.Layout.model_picker().menu
            M.session_picker = M.Layout.session_picker().menu
            local l = M.Layout.main_layout(M.popup, M.input, M.model_picker, M.session_picker)

            M.layout = l.layout
            M.layout:mount()

            --Insert initial window IDs for navigation
            M.Layout.update_window_selection()
        end

        -- Set keymaps and active session
        M.utils.set_keymaps()
        M.active_session = true
        M.active_session_shown = true

    end)

    vim.api.nvim_command("autocmd WinEnter * lua require('neollama.utils').check_window()") -- Autocmd for checking against non-neollaa win
    vim.api.nvim_command("autocmd VimResized * lua require('neollama.utils').session_resize()") -- Autocmd for detecting editor size
    if M.config.hide_cursor then
        vim.api.nvim_command("autocmd BufEnter * lua require('neollama.utils').hide_cursor()") -- Autocmd for hiding cursor if option set
    end

end

return M
