local jecs = require("@jecs")

type World = jecs.WorldShim

type Tracker<T> = { track: (world: World, fn: (changes: {
        added: () -> () -> (number, T),
        removed: () -> () -> number,
        changed: () -> () -> (number, T, T)
    }) -> ()) -> ()
}

local function diff(a, b)
    local size = 0
    for k, v in a do
        if b[k] ~= v then
            return true
        end
        size += 1
    end
    for k, v in b do
        size -= 1
    end

    if size ~= 0 then
        return true
    end

    return false
end

type Entity<T> = number & { __nominal_type_dont_use: T }

local function ChangeTracker<T>(world, T: Entity<T>): Tracker<T>
    local PreviousT = jecs.pair(jecs.Rest, T)
    local add = {}
    local added
    local removed
    local is_trivial

    local function changes_added()
        added = true
        local q = world:query(T):without(PreviousT):drain()
        return function()
            local id, data = q.next()
            if not id then
                return nil
            end

            is_trivial = typeof(data) ~= "table"

            add[id] = data

            return id, data
        end
    end

    local function changes_changed()
        local q = world:query(T, PreviousT):drain()

        return function()
            local id, new, old = q.next()
            while true do
                if not id then
                    return nil
                end

                if not is_trivial then
                    if diff(new, old) then
                        break
                    end
                elseif new ~= old then
                    break
                end

                id, new, old = q.next()
            end

            add[id] = new

            return id, old, new
        end
    end

    local function changes_removed()
        removed = true

        local q = world:query(PreviousT):without(T):drain()
        return function()
            local id = q.next()
            if id then
                world:remove(id, PreviousT)
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
        added = false
        removed = false

        fn(changes)

        if not added then
            for _ in changes_added() do
            end
        end

        if not removed then
            for _ in changes_removed() do
            end
        end

        for e, data in add do
            world:set(e, PreviousT, if is_trivial then data else table.clone(data))
        end
    end

    local tracker = { track = track }

    return tracker
end

local Vector3
do
    Vector3 = {}
    Vector3.__index = Vector3

    function Vector3.new(x, y, z)
        x = x or 0
        y = y or 0
        z = z or 0
        return setmetatable({ X = x, Y = y, Z = z }, Vector3)
    end

    function Vector3.__add(left, right)
        return Vector3.new(
            left.X + right.X,
            left.Y + right.Y,
            left.Z + right.Z
        )
    end

    function Vector3.__mul(left, right)
        if typeof(right) == "number" then
            return Vector3.new(
                left.X * right,
                left.Y * right,
                left.Z * right
            )
        end
        return Vector3.new(
            left.X * right.X,
            left.Y * right.Y,
            left.Z * right.Z
        )
    end

    Vector3.one = Vector3.new(1, 1, 1)
    Vector3.zero = Vector3.new()
end

local world = jecs.World.new()
local Name = world:component()

local function named(ctr, name)
    local e = ctr(world)
    world:set(e, Name, name)
    return e
end
local function name(e)
    return world:get(e, Name)
end

local Position = named(world.component, "Position")

-- Create the ChangeTracker with the component type to track
local PositionTracker = ChangeTracker(world, Position)

local e1 = named(world.entity, "e1")
world:set(e1, Position, Vector3.new(10, 20, 30))

local e2 = named(world.entity, "e2")
world:set(e2, Position, Vector3.new(10, 20, 30))

PositionTracker.track(function(changes)
    -- You can iterate over different types of changes: Added, Changed, Removed

    -- added queries for every entity with a new Position component
    for e, p in changes.added() do
        print(`Added {e}: \{{p.X}, {p.Y}, {p.Z}}`)
    end

    -- changed queries for entities who's changed their data since
    -- last was it tracked
    for _ in changes.changed() do
        print([[This won't print because it is the first time
                we are tracking the Position component]])
    end

    -- removed queries for entities who's removed their Position component
    -- since last it was tracked
    for _ in changes.removed() do
        print([[This won't print because it is the first time
                we are tracking the Position component]])
    end
end)

world:set(e1, Position, Vector3.new(1, 1, 2) * 999)

PositionTracker.track(function(changes)
    for e, p in changes.added() do
        print([[This won't never print no Position component was added
                since last time we tracked]])
    end

    for e, old, new in changes.changed() do
        print(`{name(e)}'s Position changed from \{{old.X}, {old.Y}, {old.Z}\} to \{{new.X}, {new.Y}, {new.Z}\}`)
    end

    -- If you don't call e.g. changes.removed() then it will automatically drain its iterator and stage their changes.
    -- This ensures you will not have any off-by-one frame errors.
end)

world:remove(e2, Position)

PositionTracker.track(function(changes)
    for e in changes.removed() do
        print(`Position was removed from {name(e)}`)
    end
end)

-- Output:
--  Added 265: {10, 20, 30}
--  Added 264: {10, 20, 30}
--  e1's Position changed from {10, 20, 30} to {999, 999, 1998}
--  Position was removed from e2
