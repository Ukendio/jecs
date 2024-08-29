--!native
--!optimize 2
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jabby = require(ReplicatedStorage.Packages.jabby)
local jecs = require(ReplicatedStorage.ecs)
local components = require(ReplicatedStorage.std.components)
local pair = jecs.pair
type World = jecs.World
type Entity<T=nil> = jecs.Entity<T>

type System = {
    callback: (world: World) -> (),
    id: number,
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
        begin: (events: Events) -> { [Entity]: thread },
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

    local scheduler

    local RenderStepped
    local Heartbeat
    local PreAnimation
    local PreSimulation

    local system: System
    local dt
    local function run()
        local id = system.id
        local system_data = scheduler.system_data[id]
		if system_data.paused then return end

		scheduler:mark_system_frame_start(id)
        system.callback(dt)
        scheduler:mark_system_frame_end(id)

    end
    local function panic(str)
        -- We don't want to interrupt the loop when we error
        task.spawn(error, str)
    end
    local function begin(events: { Systems })
        local threads = {}
        for event, systems in events  do
            if not event then continue end
            local event_name = tostring(event)
            threads[event] = task.spawn(function()
                while true do
                    dt = event:Wait()

                    debug.profilebegin(event_name)
                    for _, sys in systems do
                        system = sys
                        local didNotYield, why = xpcall(function()
                            for _ in run do end
                        end, debug.traceback)

                        if didNotYield then
            				continue
             			end

             			if string.find(why, "thread is not yieldable") then
            				panic("Not allowed to yield in the systems."
                				.. "\n"
                				.. "System: "
                				.. debug.info(system.callback, "n")
                				.. " has been ejected"
				            )
            				continue
             			end
             			panic(why)
                    end
                    debug.profileend()
                end
            end)
        end
        return threads
    end

    local function scheduler_collect_systems_under_phase_recursive(systems, phase)
        local phase_name = world:get(phase, Name)
        for _, system in world:query(System):with(pair(DependsOn, phase)) do
            table.insert(systems, {
                id = scheduler:register_system({
                    name = system.name,
                    phase = phase_name
                }),
                callback = system.callback
            })
        end
        for after in world:query(Phase):with(pair(DependsOn, phase)) do
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
        Name = world:component()

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
        for name, component in components do
            world:set(component, Name, name)
        end

        table.insert(jabby.public, {
            class_name = "World",
            name = "MyWorld",
            world = world,
            debug = Name,
            entities = {}
        })


        jabby.public.updated = true
        scheduler = jabby.scheduler.create("scheduler")

        table.insert(jabby.public, scheduler)
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
