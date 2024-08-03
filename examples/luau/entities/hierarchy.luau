local ecs = require("@jecs")
local pair = ecs.pair
local ChildOf = ecs.ChildOf
local world = ecs.World.new()

local Name = world:component()
local Position = world:component()
local Star = world:component()
local Planet = world:component()
local Moon = world:component()

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

local function path(entity)
    local str = world:get(entity, Name)
    local parent
    while true do
        parent = world:parent(entity)
        if not parent then
            break
        end
        entity = parent
        str = world:get(parent, Name) .. "/" .. str
    end
    return str
end

local function iterate(entity, parent)
    local p = world:get(entity, Position)
    local actual = p + parent
    print(path(entity))
    print(`\{{actual.X}, {actual.Y}, {actual.Z}}`)

    for child in world:query(pair(ChildOf, entity)) do
        --print(world:get(child, Name))
        iterate(child, actual)
    end
end

local sun = world:entity()
world:add(sun, Star)
world:set(sun, Position, Vector3.one)
world:set(sun, Name, "Sun")
do
    local earth = world:entity()
    world:set(earth, Name, "Earth")
    world:add(earth, pair(ChildOf, sun))
    world:add(earth, Planet)
    world:set(earth, Position, Vector3.one * 3)

    do
        local moon = world:entity()
        world:set(moon, Name, "Moon")
        world:add(moon, pair(ChildOf, earth))
        world:add(moon, Moon)
        world:set(moon, Position, Vector3.one * 0.1)

        print(`Child of Earth? {world:has(moon, pair(ChildOf, earth))}`)
    end

    local venus = world:entity()
    world:set(venus, Name, "Venus")
    world:add(venus, pair(ChildOf, sun))
    world:add(venus, Planet)
    world:set(venus, Position, Vector3.one * 2)

    local mercury = world:entity()
    world:set(mercury, Name, "Mercury")
    world:add(mercury, pair(ChildOf, sun))
    world:add(mercury, Planet)
    world:set(mercury, Position, Vector3.one)


    iterate(sun, Vector3.zero)
end

-- Output
--  Child of Earth? true
--  Sun
--  {1, 1, 1}
--  Sun/Mercury
--  {2, 2, 2}
--  Sun/Venus
--  {3, 3, 3}
--  Sun/Earth
--  {4, 4, 4}
--  Sun/Earth/Moon
--  {4.1, 4.1, 4.1}
