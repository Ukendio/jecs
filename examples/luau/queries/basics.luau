local jecs = require("@jecs")
local world = jecs.World.new()

local Position = world:component()
local Velocity = world:component()
local Name = world:component()

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

-- Create a few test entities for a Position, Velocity query
local e1 = world:entity()
world:set(e1, Name, "e1")
world:set(e1, Position, Vector3.new(10, 20, 30))
world:set(e1, Velocity, Vector3.new(1, 2, 3))

local e2 = world:entity()
world:set(e2, Name, "e2")
world:set(e2, Position, Vector3.new(10, 20, 30))
world:set(e2, Velocity, Vector3.new(4, 5, 6))

-- This entity will not match as it does not have Position, Velocity
local e3 = world:entity()
world:set(e3, Name, "e3")
world:set(e3, Position, Vector3.new(10, 20, 30))

-- Create an uncached query for Position, Velocity.
for entity, p, v in world:query(Position, Velocity) do
    -- Iterate entities matching the query
    p.X += v.X
    p.Y += v.Y
    p.Z += v.Z

    print(`{world:get(entity, Name)}: \{{p.X}, {p.Y}, {p.Z}}`)
end

-- Output:
--  e2: {14, 25, 36}
--  e1: {11, 22, 33}
