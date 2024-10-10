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
- (For web agent) htmlparser
- (For web agent) [ddgr](https://github.com/jarun/ddgr)
- (Optional) [NerdFont](https://www.nerdfonts.com/)

To install the `htmlparser` module you can use luarocks:
```bash
sudo luarocks install htmlparser
```

## Installation
To install neollama, simply use your prefferred package manager. For example using Lazy:
```lua
{
  "jaredonnell/neollama",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",
  },
}
```

## Configuration
Default config:
```lua
{
	autoscroll = true,
	hide_cursor = true, -- Decides if cursor will be hidden in menu windows
	max_chats = 10,
	hide_pasted_text = true, -- Appended visual selection will be hidden from chat wubdiw if set to true
	params = {
		model = "llama3:latest", -- Must be changed If llama3 is not available
		stream = false,
		default_options = { -- If default setting is not set the models default will be used instead
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
		extra_opts = M.api.extra_opts,
	},
	layout = {
		border = {
			default = "rounded",
		},
		size = {
			width = "70%",
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
			virtual_text = { "╒", "│", "╘" },
		},
		input = {
			icon = ">",
			text_hl = "Comment",
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
		toggle_layout = "<leader>ct",
		window_next = "}",
		window_prev = "{",
		change_config = "<leader>cs",
	},
}
```
## Usage

### Input Commands

### Config Editor

## Web Agent

## Contributing
