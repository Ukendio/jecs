local jecs = require("@jecs")
local pair = jecs.pair
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

local Eats = world:component()
local Apples = named(world.entity, "Apples")
local Oranges = named(world.entity, "Oranges")

local bob = named(world.entity, "Bob")
world:set(bob, pair(Eats, Apples), 10)

local alice = named(world.entity, "Alice")
world:set(alice, pair(Eats, Oranges), 5)

-- Aliasing the wildcard to symbols improves readability and ease of writing
local __ = jecs.Wildcard

-- Create a query that matches edible components
for entity, amount in world:query(pair(Eats, __)) do
    -- Iterate the query
    local food = world:target(entity, Eats)
    print(`{name(entity)} eats {amount} {name(food)}`)
end

-- Output:
--  Alice eats 5 Oranges
--  Bob eats 10 Apples
