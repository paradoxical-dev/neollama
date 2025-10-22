 ![Logo](https://i.imgur.com/kFkBQpJ.png)

# neollama
A UI meant for interacting with Ollama models from within Neovim.

![Preview](https://i.imgur.com/IPheacL.png)
![Preview](https://i.imgur.com/tptRHMG.png)

# Features
- Model switching with chat retention
- Session saving and reloading
- On the fly model configuration
- Visual selection appended to prompt
- Fully local built-in web agent with no external APIs

# Dependencies
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- (For web agent) gumbo
- (For web agent) [ddgr](https://github.com/jarun/ddgr)
- (Optional) [NerdFont](https://www.nerdfonts.com/)

To install the `gumbo` module you can use luarocks:
```bash
# Ensure you install for lua 5.1 (neovims current version)
sudo luarocks --lua-version=5.1 install gumbo
```
> [!WARNING]
> 
> There is an issue when using the nui dependency which requires you to be on the **main** branch of the repository.
>
> This will be changed if you update all plugins and result in an error message when opening the neollama interface
>
> To fix this simply `cd` to the location of the installed nui plugin (typically `.local/share/nvim/...` and use `git checkout main`

# Installation
To install neollama, simply use your prefferred package manager. For example, using Lazy:
```lua
{
  "paradoxical-dev/neollama",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("neollama").setup({
         -- config goes here
    })
    -- Initialization keymaps will be set externally
    vim.api.nvim_set_keymap("n","<leader>cc",'<cmd>lua require("neollama").initialize()<CR>',{ noremap = true, silent = true })
    vim.api.nvim_set_keymap("v","<leader>c",'<cmd>lua require("neollama").initialize()<CR>',{ noremap = true, silent = true })
  end)
}
```

# Configuration

<details>
  <summary>Default options:</summary>

  ```lua
  {
    autoscroll = true,
    hide_cursor = true, -- Decides if cursor will be hidden in menu windows
    max_chats = 10, -- Maximum number of persistent sessions
    hide_pasted_text = true, -- Appended visual selection will be hidden from chat window if set to true
    local_port = "http://localhost:11434/api", -- Endpoint must include /api not just the port
    params = {
      model = "llama3.1", -- Must be changed If llama3.1 is not available
      stream = false,
      default_options = { -- If a default setting is not explicitly set the models default will be used instead
        mirostat = 0,
        mirostat_eta = 0.1,
        mirostat_tau = 5.0,
        num_ctx = 2048,
        repeat_last_n = 64,
        repeat_penalty = 1.1,
        temperature = 0.8,
        seed = 0,
        tfs_z = 1.0,
        num_predict = 128,
        top_k = 40,
        top_p = 40,
      },
      extra_opts = {
        -- Visit https://github.com/ollama/ollama/blob/main/docs/api.md for example values
        num_keep = "",
        typical_p = "",
        presence_penalty = "",
        frequency_penalty = "",
        penalize_newline = "",
        numa = "",
        num_batch = "",
        num_gpu = "",
      },
    },
    web_agent = { -- See `Web Agent` section for more details
      enabled = true, -- Default option for new sessions
      manual = false,
      include_sources = true, -- Append sources or queries to chat response
      include_queries = true,
      spinner_hl = { link = "Comment" },
      user_agent = -- User-Agent header to simulate browser
      "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36",
      timeout = 15,
      content_limit = 4000, -- Word count limit for scraped content
      retry_count = 3, -- Attempts to retry a single URL before continuing
      agent_models = { -- Customize the helper agents
        use_current = true, -- If true then the below config will be ignored
        buffer_agent = { model = "llama3.2" },
        reviewing_agent = {
          model = "llama3.2",
          options = {
            num_ctx = 4096,
            temperature = 0.2,
            top_p = 0.1,
          },
        },
        integration_agent = {
          model = "llama3.1",
          options = {
            num_ctx = 4096,
          },
        },
      },
    },
    layout = {
      border = {
        default = "rounded", -- single|double|rounded|solid
      },
      size = {
        width = "70%", -- Size and position can be percent string or integer
        height = "80%",
      },
      position = "50%",
      hl = {
        title = { link = "Comment" },
        default_border = { link = "FloatBorder" },
      },
      popup = {
        hl = {
          user_header = { link = "Keyword" },
          model_header = { link = "Function" },
          virtual_text = { link = "Conditional" },
        },
        virtual_text = { "╒", "│", "╘" }, -- The text which encapsulates the model response
      },
      input = {
        icon = ">",
        hl = { link = "Comment"}, -- Controls the highlight given to the user input in the main chat window
      },
      model_picker = {
        icon = "",
        hl = { link = "Keyword" },
      },
      session_picker = {
        default_icon = "󰄰 ",
        current_icon = "󰄴 ",
        current_hl = { link = "Keyword" },
        default_hl = { link = "Comment" },
      },
    },
    keymaps = {
      -- These keymaps will only be applied when within neollama session and will be reverted when the session is hidden or closed
      toggle_layout = "<leader>ct",
      window_next = "}",
      window_prev = "{",
      change_config = "<leader>cs",
    },
  }
  ```
</details>

<details>
  <summary>Example configuration:</summary>
  
  ```lua
  {
    params = {
      model = "llama3.1:latest",
      stream = true,
    },
    web_agent = {
      agent_models = {
        use_current = false,
        buffer_agent = { model = "qwen2.5:3b" },
        reviewing_agent = { model = "qwen2.5:3b", options = { num_ctx = 4096 } },
        -- You can set any agent to use the current model using this global
        -- Any options applied to an agent using this global will not be applied to the sessions current model
        integration_agent = { model = _G.NeollamaModel, options = { temperature = 0.5 } }
      },
    },
    layout = {
      border = {
        default = "double",
      },
      input = {
        hl = { fg = "#C9C7CD", bold = true, italic = true },
      },
    },
  }
  ```
</details>

> [!NOTE]
> 
> Any helper agent which is set will not have the default options applied and will have to be explicitly set

# Usage

## Input Commands
Neollama offers three input commands for quick access to certain functionalities:

<details>
  <summary>Save command</summary>
  
  Using `/s` from the input window you are able to save the current session. 
  
  Saving the session saves all aspects of the current session including the current model with set parameters and the current chat history. 

  If ypu attempt to save a chat and the `max_xhats` limit has been reached, you'll be prompted to overwrite an existing session which will then be lost.

</details>

> [!NOTE]
>
> All sessions are saved in the neollama data directory `~/.local/share/nvim/neollama/` in the `chats.lua` file. While these are stored as lua tables, their names are not bound to typical naming conventions.

> [!WARNING]
> 
> It is not possible to set the max_chats to a lower value than the number of saved sessions, since there is no manual deletion.

<details>
  <summary>Config Editor</summary>

  
  The `/c` command allows you to enter the config editor for on-the-fly tuning of model parameters. 

  See [Config Editor](#config-editor) section for more details.
  
</details>

<details>
  <summary>Toggle web agent</summary>

  The `/w` command toggles the web_agent. The current status of the web agent is denoted by the symbol next to the model name in the main chat window.
  
</details>

## Config Editor
The config editor opens an interactive popup window which displays the set options for the current model. 

if no value is set for an option and the model has no default value, then the plugins default will be used. 

![Config Editor example](https://i.imgur.com/gSIcdmk.png)

To change a value, simply replace it's current value with the desired one. When finished editing, use the change_config command set in the configuration and the new options will be applied.

> [!NOTE]
>
> All extra options will be defaulted to an empty string unless they are set in the configuration. To edit these optiosn from the editor enter the value within the string.
>
> If the value already has a set value be sure to change the value in the extra_options table not the default_options table.

# Web Agent

## Overview
The web agent is created using sequential model calls with predefined perameters and system prompts. 

There are three main helper agents used:

### Buffer agent:

Responsible for deciding if the user's query will require a web search (if manual is set to false) and generating the proper queries for the search. 

Additionally, the results from the ddgr command, which uses the generated queries, will be fed to this model and will return the decided best URL based on the user input.

### Reviewing agent:

Used with two main goals:
  - To compile the scraped website content into relevant facts related to the user's input
  - Decide if the compiled content is adequate to answer. 

### Integration agent:

Generates the output for the user, using the compiled information. 

It's response will be treated the same as the standard model call and will be appended to the current sessions chat history.

> [!TIP]
>
> The most recent web search and agent responses can be found in the data directory mentioned earlier under web_agent.txt

## Customization
Each helper agent is completely customizeable; from the model used to the options applied to them.

It is recommended for most users to stick to a max of two smaller (3b or lower) models for the helper agents. Personally, I found qwen2.5:3b to be perfect for the reviewing and buffer agents due to its high context window for inputs.

By default, the web_agent first prompts the buffer agent on whether the user input will require a web search to fully answer.

This is done using the `requires_current_data` prompt found in [prompts.lua](/lua/neollama/web_agent/prompts.lua). 

This feature can be disabled for efficency using the `manual` option in the `web_agent` configuration where every user input (while the agent is enabled) will instead be passed to the buffer agent using the `query_gen` prompt.

The configurations default options are what I have tested to work best, but user's have the freedom to customize and test these options with any accepted value.

## Schema
The schema is best visualized using a flow chart:

![Schema flow chart](https://i.imgur.com/Z31tUKu.png)

For a better understanding of how the agent works under the hood, a good video can be found [here](https://www.youtube.com/watch?v=ZE6t9trCRnw).

It is the video I used to better grasp the concept and take inspiration from to create a lua solution.

# Contributing
Apart from bug fixes I come across in my usage, I do not plan on extending or adding features to the plugin.

If anyone *would* like to contribute, I will leave pull requests open and handle those as best I can
