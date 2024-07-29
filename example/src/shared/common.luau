--!optimize 2
--!native

local jecs = require(game:GetService("ReplicatedStorage").ecs)

type World = jecs.WorldShim
type Entity<T = any> = jecs.Entity<T>

local function LOOP_ERROR(str)
    -- We don't want to interrupt the loop when we error
    task.spawn(error, str)
end

local Scheduler: (World, ...ModuleScript) -> (number) -> ()
do
    local systems
    local N
    local w
    local dt
    local systemsNames
    local system

    local function profile()
        local name = systemsNames[system]

        debug.profilebegin(name)
        debug.setmemorycategory(name)
        system(w, dt)
        debug.profileend()
    end

    local function run(sys)
        system = sys
        return profile
    end

    local function loop(sinceLastFrame)
        debug.profilebegin("loop()")

        for i = N, 1, -1 do
            local system = systems[i]

            dt = sinceLastFrame

            local didNotYield, why = xpcall(function()
                for _ in run(system) do end
            end, debug.traceback)

            if didNotYield then
				continue
			end

			if string.find(why, "thread is not yieldable") then
				N -= 1
				table.remove(systems, i)
				LOOP_ERROR("Not allowed to yield in the systems."
    				.. "\n"
    				.. "System: "
    				.. debug.info(system, "n")
    				.. " has been ejected"
				)
			else
			    LOOP_ERROR(why)
			end
        end

        debug.profileend()
        debug.resetmemorycategory()
    end

    function Scheduler(world, ...)
        systems = { ... }
        systemsNames = {}
        N = #systems
        w = world

        for i, system in systems do
            systems[i] = require(system)
            systemsNames[system] = debug.info(system, "n")
        end

        return loop
    end
end

type Tracker<T> = { track: (world: World, fn: (changes: {
        added: () -> () -> (number, T),
        removed: () -> () -> number,
        changed: () -> () -> (number, T, T)
    }) -> ()) -> ()
}
local ChangeTracker: <T>(world: any, component: Entity<T>) -> Tracker<T>

do
    local world: World
    local T
    local PreviousT
    local addedComponents
    local removedComponents
    local isTrivial
    local added
    local removed

    local function changes_added()
        added = true
        local q = world:query(T):without(PreviousT)
        return function()
            local id, data = q:next()
            if not id then
                return nil
            end

            if isTrivial == nil then
                isTrivial = typeof(data) ~= "table"
            end

            if not isTrivial then
                data = table.clone(data)
            end

            addedComponents[id] = data
            return id, data
        end
    end

    local function shallowEq(a, b)
        for k, v in a do
            if b[k] ~= v then
                return false
            end
        end
        return true
    end

    local function changes_changed()
        local q = world:query(T, PreviousT)

        return function()
            local id, new, old = q:next()
            while true do
                if not id then
                    return nil
                end

                if not isTrivial then
                    if not shallowEq(new, old) then
                        break
                    end
                elseif new ~= old then
                    break
                end

                id, new, old = q:next()
            end

            addedComponents[id] = new

            return id, old, new
        end
    end

    local function changes_removed()
        removed = true

        local q = world:query(PreviousT):without(T)
        return function()
            local id = q:next()
            if id then
            table.insert(removedComponents, id)
            end
            return id
        end
    end

    local changes = {
        added = changes_added,
        changed = changes_changed,
        removed = changes_removed,
    }

    local function track(fn)
        added = true
        removed = true

        fn(changes)

        if not added then
            for _ in changes_added() do
            end
        end

        if not removed then
            for _ in changes_removed() do
            end
        end

        for e, data in addedComponents do
            world:set(e, PreviousT, if isTrivial then data else table.clone(data))
        end

        for _, e in removedComponents do
            world:remove(e, PreviousT)
        end
    end

    local tracker = { track = track }

    function ChangeTracker<T>(worldToTrack: World, component: Entity<T>): Tracker<T>
        world = worldToTrack
        T = component
        -- We just use jecs.Rest because people will probably not use it anyways
        PreviousT = jecs.pair(jecs.Rest, T)
        addedComponents = {}
        removedComponents = {}

        return tracker
    end
end

local Allocator: <T>(World, Entity<T>, (T) -> ()) -> { alloc: (Entity) -> (), free: (Entity) -> (), deinit: () -> () }

do
    local arena: {}
    local world
    local cleanup
    local id

    local function alloc(entity: Entity)
        table.insert(arena, entity)
    end

    local function deinit()
        for _, e in arena do
            cleanup(world:get(e, id), e)
            world:clear(e)
        end
    end

    local function free(entity: Entity)
        local e = table.remove(arena, table.find(arena, entity))
        if e then
            cleanup(world:get(e, id), e)
            world:clear(e)
        end
    end

    local handle = {
        alloc = alloc,
        deinit = deinit,
        free = free,
    }

    setmetatable(handle, handle)

    function Allocator<T>(w: World, T: Entity<T>, fn: (T) -> ())
        arena = {}
        world = w
        cleanup = fn
        id = T

        return handle
    end
end

local world = jecs.World.new()
local Model = world:component() :: Entity<Model>

local ModelAllocator = Allocator(world,
    Model, function(model) model:Destroy() end)

local e = world:entity()
world:set(e, Model, Instance.new("Model"))

ModelAllocator.alloc(e)
ModelAllocator.free(e)

return {
    Scheduler = Scheduler,
    ChangeTracker = ChangeTracker,
    Allocator = Allocator
}
