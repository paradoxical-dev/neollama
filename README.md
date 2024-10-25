# neollama
A UI meant for interacting with Ollama models from within Neovim.

## Features
- Model switching with chat retention
- Session saving and reloading
- On the fly model configuration
- Visual selection appended to prompt
- Built-in web agent

## Dependencies
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

## Installation
To install neollama, simply use your prefferred package manager. For example, using Lazy:
```lua
{
  "jaredonnell/neollama",
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

## Configuration
Default options:
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
		enabled = true,
		manual = true,
		include_sources = true, -- Append sources or queries to chat response
		include_queries = true,
		spinner_hl = { link = "Comment" },
		user_agent = -- User-Agent header to simulate browser
		"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36",
		timeout = 15,
		content_limit = 4000, -- Word count limit for scraped content
		retry_count = 3, -- Attempts to retry a single URL before continuing
		agent_models = { -- Customize the helper agents
			use_current = true,
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
			hl = { link = "Comment"},
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

Example configuration:

## Usage

### Input Commands
Neollama offers three input commands for quick access to certain functionalities:

- **`/s`**

Using `/s` from the input window you are able to save the current session. Saving the session saves all aspects of the current session including the current model with set parameters and the current chat history. If ypu attempt to save a chat and the `max_xhats` limit has been reached, you'll be prompted to overwrite an existing session which will then be lost.
>**NOTE**
>
>All sessions are saved in the neollama data directory `~/.local/share/nvim/neollama/` in the `chats.lua` file. While these are stored as lua tables, their names are not bound to typical naming conventions.
>
>Additionally, it is not possible to set the max_chats to a lower value than the number of saved sessions, since there is no manual deletion.

- **`/c`**

The `/c` command allows you to enter the config editor for on-the-fly tuning of model parameters. See Config Editor section for more details.

- **`/w`**

The `/w` command toggles the web_agent. The current status of the web agent is denoted by the symbol next to the model name in the main chat window.

### Config Editor

## Web Agent

### Overview
The web agent is created using sequential model calls with predefined perameters and system prompts. There are three main helper agents used:
- **Buffer agent**

The buffer agent is responsible for deciding if the user's query will require a web search (if manual is set to false) and generating the proper queries for the search. Additionally, the results from the ddgr command, which uses the generated queries, will be fed to this model and will return the decided best URL based on the user input.

- **Reviewing agent**

The reviewing agent will be used with two main goals: 
  - To compile the scraped website content into relevant facts related to the user's input
  - Decide if the compiled content is adequate to answer. 

- **Integration agent**

The integration agent is used to generate the output for the user, using the compiled information. It's response will be treated the same as the standard model call and will be appended to the current sessions chat history.

Using these helper agents, we're able to enter a feedback loop of choosing a URL from a query, scraping it's content, deciding if the content is enough to answer the user's query, and either repeating the process with the next set of queries or generating the final output to be presented to the user.

## Contributing
