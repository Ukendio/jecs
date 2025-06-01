local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jabby = require(ReplicatedStorage.Packages.jabby)
local jecs = require(ReplicatedStorage.ecs)

jabby.set_check_function(function() return true end)

local scheduler = jabby.scheduler.create("jabby scheduler")

jabby.register({
	applet = jabby.applets.scheduler,
	name = "Scheduler",
	configuration = {
		scheduler = scheduler,
	},
})

local ContextActionService = game:GetService("ContextActionService")

local function create_widget(_, state: Enum.UserInputState)
	local client = jabby.obtain_client()
    if state ~= Enum.UserInputState.Begin then return end
    client.spawn_app(client.apps.home, nil)
end

local RunService = game:GetService("RunService")

local System = jecs.component() :: jecs.Id<{
	fn: () -> (),
	name: string,
}>
local DependsOn = jecs.component()
local Phase = jecs.tag()
local Event = jecs.component() :: jecs.Id<RBXScriptSignal>

local pair = jecs.pair

local types = require(ReplicatedStorage.types)

local function ECS_PHASE(world, after: types.Entity)
	local phase = world:entity()
	world:add(phase, Phase)
	if after then
		local dependency = pair(DependsOn, after)
		world:add(phase, dependency)
	end

	return phase
end

local Heartbeat = jecs.tag()
jecs.meta(Heartbeat, Phase)
jecs.meta(Heartbeat, Event, RunService.Heartbeat)

local PreSimulation = jecs.tag()
jecs.meta(PreSimulation, Phase)
jecs.meta(PreSimulation, Event, RunService.PreSimulation)

local PreAnimation = jecs.tag()
jecs.meta(PreAnimation, Phase)
jecs.meta(PreAnimation, Event, RunService.PreAnimation)

local PreRender = jecs.tag()
jecs.meta(PreRender, Phase)
jecs.meta(PreRender, Event, RunService.PreRender)

local function ECS_SYSTEM(world: types.World, mod: ModuleScript, phase: types.Entity?)
	local system = world:entity()
	local p = phase or Heartbeat
	local fn = require(mod) :: (...any) -> ()
	world:set(system, System, {
		fn = fn(world, 0) or fn,
		name = mod.Name,
	})

	local depends_on = DependsOn :: jecs.Entity
	world:add(system, pair(depends_on, p))
end
local function find_systems_w_phase(world: types.World, systems, phase: types.Entity)
	local phase_name = world:get(phase, jecs.Name) :: string
	for _, s in world:query(System):with(pair(DependsOn, phase)) do
		table.insert(systems, {
			id = scheduler:register_system({
				phase = phase_name,
				name = s.name,
			}),
			fn = s.fn
		})
	end
	for after in world:query(Phase, pair(DependsOn, phase)) do
		find_systems_w_phase(world, systems, after)
	end
	return systems
end

local function ECS_RUN(world: types.World)

	jabby.register({
		applet = jabby.applets.world,
		name = "MyWorld",
		configuration = {
			world = world,
		},
	})

	if RunService:IsClient() then
		ContextActionService:BindAction("Open Jabby Home", create_widget, false, Enum.KeyCode.F4)
	end

	for phase, event in world:query(Event, Phase) do
		local systems = find_systems_w_phase(world, {}, phase)
		event:Connect(function(...)
			for _, system in systems do
				scheduler:run(system.id, system.fn, world, ...)
			end
		end)
	end

end

return {
	PHASE = ECS_PHASE,
	SYSTEM = ECS_SYSTEM,
	RUN = ECS_RUN,
	phases = {
		Heartbeat = Heartbeat,
		PreSimulation = PreSimulation,
		PreAnimation = PreAnimation,
		PreRender = PreRender
	},
	components = {
		System = System,
		DependsOn = DependsOn,
		Phase = Phase,
		Event = Event,
	}
}
