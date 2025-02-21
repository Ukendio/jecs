--!native
--!optimize 2
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local jabby = require(ReplicatedStorage.Packages.jabby)
local jecs = require(ReplicatedStorage.ecs)
local pair = jecs.pair
local Name = jecs.Name

type World = jecs.World
type Entity<T = nil> = jecs.Entity<T>
type Id<T = unknown> = jecs.Id<T>

type System = {
	callback: (world: World) -> (),
	id: number,
}

type Systems = { System }

type Events = {
	RenderStepped: Systems,
	Heartbeat: Systems,
}

local world = require(script.Parent.world)
local Disabled = world:entity()
local System = world:component() :: Id<{ callback: (any) -> (), name: string}>
local DependsOn = world:entity()
local Event = world:component() :: Id<RBXScriptSignal>
local Phase = world:entity()

local PreRender = world:entity()
local Heartbeat = world:entity()
local PreAnimation = world:entity()
local PreSimulation = world:entity()

local sys: System
local dt: number

local jabby_scheduler = jabby.scheduler.create("Scheduler")

local a, b, c, d
local function run()
	local id = sys.id
	jabby_scheduler:run(id, sys.callback, a, b, c, d)
	return nil
end

world:add(Heartbeat, Phase)
world:set(Heartbeat, Event, RunService.Heartbeat)

world:add(PreSimulation, Phase)
world:set(PreSimulation, Event, RunService.PreSimulation)

world:add(PreAnimation, Phase)
world:set(PreAnimation, Event, RunService.PreAnimation)

jabby.register({
	applet = jabby.applets.world,
	name = "MyWorld",
	configuration = {
	world = world,
	},
})

jabby.register({
	applet = jabby.applets.scheduler,
	name = "Scheduler",
	configuration = {
		scheduler = jabby_scheduler,
	},
})

if RunService:IsClient() then 
	world:add(PreRender, Phase)
	world:set(PreRender, Event, (RunService :: RunService).PreRender)
end

local function begin(events: { [RBXScriptSignal]: Systems })
	local connections = {}
	for event, systems in events do
		if not event then
			continue
		end
		local event_name = tostring(event)
		connections[event] = event:Connect(function(...)
			debug.profilebegin(event_name)
			for _, s in systems do
				sys = s
				a, b, c, d = ...

				for _ in run do
					break
				end

			end
			debug.profileend()
		end)
	end
	return connections
end

local function scheduler_collect_systems_under_phase_recursive(systems, phase: Entity)
	local phase_name = world:get(phase, Name)
	for _, s in world:query(System):with(pair(DependsOn, phase)) do
		table.insert(systems, {
			id = jabby_scheduler:register_system({
				name = s.name,
				phase = phase_name,
			} :: any),
			callback = s.callback,
		})
	end
	for after in world:query(Phase):with(pair(DependsOn, phase)):iter() do
		scheduler_collect_systems_under_phase_recursive(systems, after)
	end
end

local function scheduler_collect_systems_under_event(event)
	local systems = {}
	scheduler_collect_systems_under_phase_recursive(systems, event)
	return systems
end

local function scheduler_collect_systems_all()
	local events = {}
	for phase, event in world:query(Event):with(Phase) do
		events[event] = scheduler_collect_systems_under_event(phase)
	end
	return events
end

local function scheduler_phase_new(d: { after: Entity?, event: RBXScriptSignal? })
	local phase = world:entity()
	world:add(phase, Phase)
	local after = d.after
	if after then 
		local dependency = pair(DependsOn, after :: Entity)
		world:add(phase, dependency)
	end
	
	local event = d.event
	if event then 
		world:set(phase, Event, event)
	end
	return phase
end

local function scheduler_systems_new(callback: (any) -> (), phase: Entity?) 
	local system = world:entity()
	world:set(system, System, { callback = callback, name = debug.info(callback, "n") })
	local depends_on = DependsOn :: jecs.Entity
	local p: Entity = phase or Heartbeat
	world:add(system, pair(depends_on, p))
	
	return system
end

return {
	SYSTEM = scheduler_systems_new,
	BEGIN = begin,
	PHASE = scheduler_phase_new, 
	COLLECT = scheduler_collect_systems_all,
	phases = {
		Heartbeat = Heartbeat,
		PreSimulation = PreSimulation,
		PreAnimation = PreAnimation,
		PreRender = PreRender
	}
}
