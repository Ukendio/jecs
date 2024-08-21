--!native
--!optimize 2
local jecs = require(game:GetService("ReplicatedStorage").ecs)
local pair = jecs.pair
type World = jecs.World
type Entity<T=nil> = jecs.Entity<T>

type System = {
    callback: (world: World) -> ()
}

type Systems = { System }


type Events = {
    RenderStepped: Systems,
    Heartbeat: Systems
}

export type Scheduler = {
    components: {
        Disabled: Entity,
        System: Entity<System>,
        Phase: Entity,
        DependsOn: Entity
    },

    collect: {
        under_event: (event: Entity) -> Systems,
        all: () -> Events
    },

    systems: {
        begin: (events: Events) -> (),
        new: (callback: (dt: number) -> (), phase: Entity) -> Entity
    },

    phases: {
        RenderStepped: Entity,
        Heartbeat: Entity
    },

    phase: (after: Entity) -> Entity
}

local scheduler_new: (w: World) -> Scheduler

do
    local world
    local Disabled
    local System
    local DependsOn
    local Phase
    local Event
    local Name

    local RenderStepped
    local Heartbeat
    local PreAnimation
    local PreSimulation

    local system
    local dt
    local function run()
        debug.profilebegin(system.name)
        system.callback(dt)
        debug.profileend()
    end
    local function panic(str)
        -- We don't want to interrupt the loop when we error
        task.spawn(error, str)
    end
    local function begin(events)
        local connections = {}
        for event, systems in events do

            if not event then continue end
            local event_name = tostring(event)
            connections[event] = event:Connect(function(last)
                debug.profilebegin(event_name)
                for _, sys in systems do
                    system = sys
                    dt = last

                    local didNotYield, why = xpcall(function()
                        for _ in run do end
                    end, debug.traceback)

                    if didNotYield then
             			continue
              		end

              		if string.find(why, "thread is not yieldable") then
             			panic("Not allowed to yield in the systems.")
              		else
              		    panic(why)
              		end
                end
                debug.profileend()
            end)
        end
        return connections
    end

    local function scheduler_collect_systems_under_phase_recursive(systems, phase)
        for _, system in world:query(System):with(pair(DependsOn, phase)) do
            table.insert(systems, system)
        end
        for dependant in world:query(Phase):with(pair(DependsOn, phase)) do
            scheduler_collect_systems_under_phase_recursive(systems, dependant)
        end
    end

    local function scheduler_collect_systems_under_event(event)
        local systems = {}
        scheduler_collect_systems_under_phase_recursive(systems, event)
        return systems
    end

    local function scheduler_collect_systems_all()
        local systems = {}
        for phase, event in world:query(Event):with(Phase) do
            systems[event] = scheduler_collect_systems_under_event(phase)
        end
        return systems
    end

    local function scheduler_phase_new(after)
        local phase = world:entity()
        world:add(phase, Phase)
        local dependency = pair(DependsOn, after)
        world:add(phase, dependency)
        return phase
    end

    local function scheduler_systems_new(callback, phase)
        local system = world:entity()
        local name = debug.info(callback, "n")
        world:set(system, System, { callback = callback, name = name })
        world:add(system, pair(DependsOn, phase))
        return system
    end

    function scheduler_new(w)
        world = w
        Disabled = world:component()
        System = world:component()
        Phase = world:component()
        DependsOn = world:component()
        Event = world:component()

        RenderStepped = world:component()
        Heartbeat = world:component()
        PreSimulation = world:component()
        PreAnimation = world:component()

        local RunService = game:GetService("RunService")
        if RunService:IsClient() then
            world:add(RenderStepped, Phase)
            world:set(RenderStepped, Event, RunService.RenderStepped)
        end

        world:add(Heartbeat, Phase)
        world:set(Heartbeat, Event, RunService.Heartbeat)

        world:add(PreSimulation, Phase)
        world:set(PreSimulation, Event, RunService.PreSimulation)

        world:add(PreAnimation, Phase)
        world:set(PreAnimation, Event, RunService.PreAnimation)

        return {
            phase = scheduler_phase_new,

            phases = {
                RenderStepped = RenderStepped,
                PreSimulation = PreSimulation,
                Heartbeat = Heartbeat,
                PreAnimation = PreAnimation
            },

            world = world,

            components = {
                DependsOn = DependsOn,
                Disabled = Disabled,
                Phase = Phase,
                System = System,
            },

            collect = {
                under_event = scheduler_collect_systems_under_event,
                all = scheduler_collect_systems_all
            },

            systems = {
                new = scheduler_systems_new,
                begin = begin
            }
        }
    end
end


return {
    new = scheduler_new
}
