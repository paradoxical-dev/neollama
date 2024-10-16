local M = {}

M.setup = function(api, layout, input, util, init, agent, scraper)
	api.set_layout_handler(layout)
	api.set_plugin(init)
	api.set_utils(util)

	layout.set_api(api)
	layout.set_plugin(init)
	layout.set_input(input)
	layout.set_utils(util)

	input.set_api(api)
	input.set_layout_handler(layout)
	input.set_plugin(init)
	input.set_agent(agent, scraper)

	util.set_plugin(init)
	util.set_layout_handler(layout)
	util.set_api(api)

	agent.set_plugin(init)

	scraper.set_plugin(init)
end

return M
