local job = require('plenary.job')

local M = {}

local LayoutHandler
local plugin
local utils

M.set_layout_handler = function(handler)
    LayoutHandler = handler
end

M.set_plugin = function(init)
    plugin = init
end

M.set_utils = function (util)
    utils = util
end

--[[ Automatic values for all available default options
does not include the current paramters of the loaded model by defualt ]]
M.default_options = {
    mirostat = 0,
    mirostat_eta = 0.1,
    mirostat_tau = 5.0,
    num_ctx = 2048,
    repeat_last_n = 64,
    repeat_penalty = 1.1,
    temperature = 0.8,
    seed = 0,
    stop = {},
    tfs_z = 1.0,
    num_predict = 128,
    top_k = 40,
    top_p = 40,
}

--[[ Additional options with no default value 
will only be set if explictely assigned a value ]]
M.extra_opts = {
    -- go to ollama docs for example values
    num_keep = '',
    typical_p = '',
    presence_penalty = '',
    frequency_penalty = '',
    penalize_newline = '',
    numa = '',
    num_batch = '',
    num_gpu = '',
}

-- state of ollama client
M.done = false
M.model_loaded = false

-- M.params = {
--     model = _G.NeollamaModel,
--     messages = {},
--     stream = plugin.config.params.stream,
--     opts = M.default_options,
-- }

-- Default the response to an empty string for streamed responses
M.constructed_response = ""

--[[ Function to handle newlines and line breaks in streamed responses
returns a table of the split lines with the first containing the current line concatenated to the chunk ]]
M.separate_chunk = function (chunk)
    local t = {}

    local lines = vim.api.nvim_buf_get_lines(plugin.popup.bufnr, 0, -1, false)
    local current_line = lines[#lines]

    if chunk == '\n' then
        t = {"  ", "  "}
        return t
    elseif chunk:find('\n') then
        local sep = "\n"
        local counter = 0
        for line in chunk:gmatch("([^"..sep.."]+)") do
            if counter == 0 then
                table.insert(t, current_line .. line)
                table.insert(t, "  ")
                counter = counter + 1
                goto continue
            else
                table.insert(t, line)
                counter = counter + 1
            end

            ::continue::
        end
        return t
    else
        table.insert(t, current_line .. chunk)
        return t
    end
end

-- Handling of the data from `separate_chunk`
M.handle_stream = function (chunk)
    local lines = vim.api.nvim_buf_get_lines(plugin.popup.bufnr, 0, -1, false)
    local current_line = lines[#lines]
    local line_count = vim.api.nvim_buf_line_count(plugin.popup.bufnr)

    local separated_response = M.separate_chunk(chunk)
    if separated_response == {"  ", "  "} then
        vim.api.nvim_buf_set_lines(plugin.popup.bufnr, line_count + 1, line_count + 1, false, separated_response)
        return
    end
    local wrapped_line = utils.line_wrap(current_line .. chunk, plugin.popup._.size.width - 2)

    if separated_response[1] == (nil or "  " or "\n") then
        vim.api.nvim_buf_set_lines(plugin.popup.bufnr, line_count + 1, line_count + 1, false, separated_response)
    elseif #wrapped_line > 1 then
        -- Add additional lines to split response
        separated_response[1] = '  ' .. wrapped_line[1]
        for i, v in ipairs(wrapped_line) do
            if i ~= 1 and not string.find(separated_response[1], v) then
                table.insert(separated_response, '  ' .. v)
            end
        end

        vim.api.nvim_buf_set_lines(plugin.popup.bufnr, line_count - 1 , -1, false, separated_response)
    else
        vim.api.nvim_buf_set_lines(plugin.popup.bufnr, line_count - 1, line_count, false, separated_response)
    end
end

--[[ format the string response to paragraphs/sections
ensure proper spcaing between text groups by searching for header characters ]]
M.response_split = function(response)
    local sep = "\n"
    local open_block = false
    local t = {}
    table.insert(t, _G.NeollamaModel.. ':')
    table.insert(t,'')
    for str in string.gmatch(response, "([^"..sep.."]+)") do
        -- Checks for markdown header characters for section separation
        if string.find(str, '%*%*') or string.find(str, '#') then
            table.insert(t,'')
        end
        --[[ Checks for code blocks and determins whether they are open or closed as well as determining 
        if code blocks hava a defined language; adding a placeholder language if needed ]]
        if string.find(str, '```') and not open_block then
            if string.match(str, '```.+') then
                open_block = true
            else
                local language = 'javascript'
                str = str .. language
                open_block = true
            end
        elseif string.find(str, '```') then
            open_block = false
        end

        if not vim.api.nvim_win_is_valid(plugin.popup.winid) then
            LayoutHandler.update_window_selection()
        end
        if vim.fn.strdisplaywidth(str) >= vim.api.nvim_win_get_width(plugin.popup.winid) then
            local wrapped_line = utils.line_wrap(str, plugin.popup._.size.width - 2)
            for _, line in ipairs(wrapped_line) do
                table.insert(t, '  ' .. line)
            end
        else
            table.insert(t,'  ' .. str)
        end
    end
    table.insert(t,'')
    table.insert(t,'')
    return t
end

-- Provides an empty request to the designated model upon startup to inprove response times
M.load_model = function (model)
    local port = 'http://localhost:11434/api/generate' -- Local port where Ollama API is hosted
    local params = {
        model = model
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
        command = 'curl',
        args = args,
        cwd = '/usr/bin',
        on_stderr = function (err)
            print('Error: ', err)
        end,
        on_exit = vim.schedule_wrap(function (j, return_val)
            if return_val == 0 then
                M.model_loaded = true
            else
                print('Error loading model: ' .. _G.NeollamaModel .. ' check your API connection and try again')
            end
        end)
    }):start()

end

-- Generate a list of all available local models
M.list_models = function ()
    local port = 'http://localhost:11434/api/tags' -- Local port where Ollama API is hosted
    local args = {
        "--silent",
        "--show-error",
        "--no-buffer",
        port,
    }
    job:new({
        command = 'curl',
        args = args,
        cwd = '/usr/bin',
        on_stderr = function (err)
            print('Error:', err)
        end,
        on_exit = function (j, return_val)
            local raw_response = j:result()

            local json_strings = {}
            for json_str in raw_response[1]:gmatch('%b{}') do
                table.insert(json_strings, json_str)
            end

            local processed_response = {}
            for _, json_str in ipairs(json_strings) do
                local decoded = vim.json.decode(json_str)
                table.insert(processed_response, decoded)
            end

            local res = processed_response[1]
            local model_list = {}
            for i, _ in pairs(res.models) do
                table.insert(model_list, res.models[i].name)
            end
            M.model_list = model_list
        end
    }):start()
end

-- Grabs and recontructs the params of the current model into a lua table before updating the current opts using the `insert_model_opts` callback
M.get_opts = function ()
    local port = 'http://localhost:11434/api/show'
    local params = {name = _G.NeollamaModel}
    job:new({
        command = 'curl',
        args = {
            "--silent",
            "--show-error",
            "--no-buffer",
            port,
            "-H",
            "Content-Type: application/json",
            "-d",
            vim.json.encode(params)
        },
        cwd = '/usr/bin',
        on_stderr = function (err)
            print('Error occured while accessing model parameters', 'Error: ' .. err)
        end,
        on_exit = function (j, return_val)

            local res = vim.json.decode(j:result()[1])
            local model_paramaters = res.parameters

            local vals = {}
            for word in model_paramaters:gmatch("%S+") do
                table.insert(vals, word)
            end

            local constructed_params = {
                stop = {},
            }

            for i, param in ipairs(vals) do
                if i == 1 and param ~= 'stop' then
                    if vals[i + 1]:match("^%-?%d+%.?%d*$") ~= nil then
                        local numeric_value = tonumber(vals[i + 1])
                        constructed_params[param] = numeric_value
                    else
                        constructed_params[param] = vals[i + 1]
                    end
                elseif param == 'stop' then
                    table.insert(constructed_params.stop, vals[i + 1])
                elseif constructed_params[vals[i - 1]] == param or vals[i - 1] == 'stop' or constructed_params[vals[i - 1]] == tonumber(param) then
                    goto continue
                elseif i == #vals - 2 or vals[i + 1] == nil then
                    break
                else
                    if vals[i + 1]:match("^%-?%d+%.?%d*$") ~= nil then
                        local numeric_value = tonumber(vals[i + 1])
                        constructed_params[param] = numeric_value
                    else
                        constructed_params[param] = vals[i + 1]
                    end
                end
                ::continue::
            end
            M.model_opts = constructed_params

            M.insert_model_opts(M.model_opts)
        end
    }):start()
end

-- Updates the opts paramater to match the models opts
M.insert_model_opts = function (model_opts)
    for option, value in pairs(model_opts) do
        if M.params.opts[option] == nil then
            M.extra_opts[option] = value
        elseif M.extra_opts[option] ~= ('' or nil) then
            M.params.opts[option] = value
        else
            M.params.opts[option] = value
        end
    end
    M.opts_check()
end


-- Checks values of extra opts and inserts them into the opts paramater if the value has been set
M.opts_check = function ()
    for option, value in pairs(M.extra_opts) do
        if value ~= '' then
            if tonumber(value) == nil then
                M.params.opts[option] = value
            else
                M.params.opts[option] = tonumber(value)
            end
        end
    end
end

-- Removes any external options that may have been set when switching models
M.reset_opts = function ()
    M.params.opts = M.default_options
    for option, value in pairs(M.extra_opts) do
        if value ~= '' then
            M.extra_opts[option] = ''
        end
    end
end


--[[ Creates and executes a job using the curl command,
passes in API request body with additional arguments ]]
M.ollamaCall = function()
    local port = 'http://localhost:11434/api/chat' -- Local port where Ollama API is hosted

    local args = {
        "--silent",
        "--show-error",
        "--no-buffer",
        port,
        "-H",
        "Content-Type: application/json",
        "-d",
        vim.json.encode(M.params),
    }
    job:new({
        command = 'curl',
        args = args,
        cwd = '/usr/bin',
        on_stdout = vim.schedule_wrap(function (err, value)
            if err then 
                print('Error: ' .. err)
                return
            end
            if M.params.stream then
                local res = vim.json.decode(value)
                local chunk = res.message.content

                M.constructed_response = M.constructed_response .. chunk
                M.handle_stream(chunk)

                if plugin.config.autoscroll then
                    vim.cmd('stopinsert')
                    vim.cmd('normal G$')
                end
            end
        end),
        on_stderr = function (err)
            print('Error: ', err)
        end,
        on_exit = function (j, return_val)
            local raw_response = j:result()
            local response = vim.json.decode(raw_response[1])
            if not M.params.stream then
                table.insert(M.params.messages, #M.params.messages + 1, response.message)
            else
                local response_table = {
                    role = "assistant",
                    content = M.constructed_response
                }
                table.insert(M.params.messages, #M.params.messages + 1, response_table)
            end
            M.done = true
        end
    }):start()
end

return M
