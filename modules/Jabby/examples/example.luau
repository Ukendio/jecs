local RunService = game:GetService("RunService")

local jecs = require("@jecs")
local jabby = require("@modules/jabby")

local world = jecs.world()

jabby.set_check_function(function()
	return true
end)

local scheduler = jabby.scheduler.create()

jabby.register({
	applet = jabby.applets.scheduler,
	name = "Example Scheduler",
	configuration = {
		scheduler = scheduler,
	},
})

jabby.register({
	applet = jabby.applets.world,
	name = "Example World",
	configuration = {
		world = world,
	},
})

local system_id = scheduler:register_system({
	name = "example_system",
	module = script,
})

local function example_system(_world: jecs.World, dt: number)
	return dt
end

if RunService:IsClient() then
	local client = jabby.obtain_client()
	client.spawn_app(client.apps.home, nil)
end

RunService.Heartbeat:Connect(function(dt)
	scheduler:run(system_id, example_system, world, dt)
end)
