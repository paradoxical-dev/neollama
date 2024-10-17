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

M.integration_prompt = function(input)
  local prompt = [[
  You are an AI agent responsible for providing a comprehensive and well-structured response to the user's input based on the given information. Your goal is to address every relevant aspect of the user's query. Ensure your response is clear, concise, and accurate, while making use of any provided information. The user's input is as follows: "]] ..
  input .. [["

  Use the information provided to support your answer and ensure you cover all key points in the input. Be precise, avoid unnecessary details, and tailor your response to the user's specific query.
  ]]
  return prompt
end

M.response_checker_prompt = function(user_input, content)
  local prompt = [[
  You are an AI agent responsible for assessing whether the provided information is sufficient to fully and accurately answer the user's prompt. Your task is to determine if all relevant aspects of the user's query can be addressed using the given content. If the provided information is enough, return a JSON object with `"res_passed": true`. If not, return `"res_passed": false`.

  Here is the user's prompt: "]] .. user_input .. [["

  The information in question will be provided to you.

  Analyze the content to decide if it is adequate to answer the user's query completely. Return your result in the following JSON format:
  {
    "res_passed": true
  }

  or

  {
    "res_passed": false
  }
  ]]
  return prompt
end

M.site_select = function(user_input, failed_sites)
  local prompt = [[
  You are tasked with selecting a website from a list of websites based on the user's input. The user's input was: "]] ..
  user_input .. [[
  Ensure the chosen URL does not match any of the following websites which have been maked as failed sites: ]] ..
  table.concat(
    failed_sites,
    "\n"
  ) .. [[
  Provide only the chosen website URL with no other information or context
  ]]

  return prompt
end

M.compile_info = function(user_input)
  local prompt = [[
  You are tasked with compiling information from a website based on the user's input. The user's input was: "]] ..
  user_input .. [[
  You will be given the content of the website. Provide only the compiled information with no other context. Do not alter the provided information, only including snippets of the relevant points and facts in its original order
  ]]
  return prompt
end

return M
