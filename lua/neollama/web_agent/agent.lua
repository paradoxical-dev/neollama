local job = require("plenary.job")
local prompts = require("neollama.web_agent.prompts")
local utils = require("neollama.utils")

local M = {}

M.requires_current_data = function(user_prompt)
  local res
  local port = "http://localhost:11434/api/chat" -- Local port where Ollama API is hosted
  local params = {
    model = "llama3.1",                         -- replace with configured model,
    messages = {
      { role = "system", content = prompts.requires_current_data },
      { role = "user",   content = user_prompt },
    },
    format = "json",
    stream = false,
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
    command = "curl",
    args = args,
    cwd = "/usr/bin",
    on_stderr = function(err)
      print("Error: ", err)
    end,
    on_exit = function(j, _)
      local raw_response = vim.json.decode(j:result()[1])
      res = vim.json.decode(raw_response.message.content)
      M.web_search = res
    end,
  }):start()
end

M.requires_current_data("What is the current weather in London?")
if not M.web_search then
  utils.setTimeout(0.25, function()
    print(vim.inspect(M.web_search))
  end, function()
    return M.web_search
  end)
end
return M
