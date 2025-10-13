--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jabby = require(ReplicatedStorage.Packages.jabby)
local ct = require(ReplicatedStorage.components)
local jecs = require(ReplicatedStorage.ecs)

jabby.set_check_function(function(player) return true end)

local scheduler = jabby.scheduler.create()

jabby.register({
	applet = jabby.applets.scheduler,
	name = "Scheduler",
	configuration = {
		scheduler = scheduler,
	},
}::any)

local ContextActionService = game:GetService("ContextActionService")

local function create_widget(_, state: Enum.UserInputState): Enum.ContextActionResult
	local client = jabby.obtain_client()
    if state ~= Enum.UserInputState.Begin then
    	return Enum.ContextActionResult.Pass
    end
    client.spawn_app(client.apps.home::any, nil)
    return Enum.ContextActionResult.Sink
end

local RunService = game:GetService("RunService")

local function schedule(world, ...)
	local function get_entity_from_part(part: BasePart): (jecs.Entity<any>?, PVInstance?)
		for id, model in world:query(ct.Renderable) do
			if not part:IsDescendantOf(model) then continue end
			return id, model
		end
		return nil, nil
	end

	jabby.register({
		applet = jabby.applets.world,
		name = "World",
		configuration = {
			world = world,
			get_entity_from_part = get_entity_from_part,
		},
	}::any)

	local systems = { ... }

	local function systems_load(mod: ModuleScript, ...)
		local fn = require(mod) :: (...any) -> ()
		local system = fn(...) or fn

		local system_id = scheduler:register_system({
			name = mod.Name,
			module = mod,
		})

		return {
			system = system,
			id = system_id
		}
	end

	for i, mod in systems do
		systems[i] = systems_load(mod, world, 0)
	end

	if RunService:IsClient() then
		ContextActionService:BindAction(
			"Open Jabby Home",
			create_widget,
			false,
			Enum.KeyCode.F4
		)
	end

	return function(dt: number, input: InputObject?)
		for i, config in systems do
			-- config.system(world, dt, input)
			local system = config.system
			local id = config.id
			scheduler:run(id, system,
				world, dt, input)
		end
	end
end

return schedule
