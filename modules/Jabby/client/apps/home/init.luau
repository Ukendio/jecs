local RunService = game:GetService("RunService")

local vide = require(script.Parent.Parent.Parent.vide)
local loop = require(script.Parent.Parent.Parent.modules.loop)
local widget = require(script.widget)

local cleanup = vide.cleanup

local home = {
	class_name = "app" :: "app",
	name = "Home"
}

function home.mount(_: nil, destroy: () -> ())

	local servers = vide.source {} :: any
	local app_loop = loop (
		"app-client-home",
		servers,

		{i = 1},
		script.systems.get_core_data
	)

	cleanup(
		RunService.Heartbeat:Connect(app_loop)
	)

	return widget {
		servers = servers,
		destroy = destroy
	}

end

return home