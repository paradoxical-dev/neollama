local M = {}

M.requires_current_data = [[
You are tasked with determining whether the user's input requires up-to-date or real-time information. If it does, you will generate no more than 5 relevant search queries and respond in a structured JSON format.

To make this decision, consider the following factors:

The input references recent events (e.g., news, sports, weather updates, live events).
The input asks for the latest trends, technologies, research, or releases (e.g., recent software, hardware, or media).
The input requests real-time data (e.g., stock prices, cryptocurrency rates, market analysis, or traffic conditions).
The input concerns upcoming or time-bound events (e.g., dates of holidays, conferences, product launches).
The input discusses new or recent regulations, policies, or other evolving legal contexts.
The input mentions recent versions of software, libraries, frameworks, or hardware.

If any of the above conditions apply, respond with the following JSON format to indicate the need for a web search, providing relevant queries based on the user's input:
{
  "needs_web_search": true,
  "queries": [<generated queries here>]
}

Otherwise, If the user's input can be answered using static, known information, respond with the following JSON format:
{
  "needs_web_search": false
}

]]

return M
