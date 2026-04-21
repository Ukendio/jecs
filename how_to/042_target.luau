--[[
	world:target(entity, relation, index?) returns the target of a relationship
	on an entity. The index is 0-based. If no target exists at that index, it
	returns nil.

	Use target when you have queried with a wildcard (e.g. pair(Eats, jecs.Wildcard))
	and need the actual target entity for each result. Without an index, the
	default is 0 (the first target).

	world:targets(entity, relation) returns an iterator for all targets of a relation.
	
	Use targets when you need to get every possible target for all indexes.
]]

local jecs = require("@jecs")
local pair = jecs.pair
local world = jecs.world()

local Eats = world:entity()
local Apples = world:entity()
local Oranges = world:entity()
local bob = world:entity()

world:add(bob, pair(Eats, Apples))
world:add(bob, pair(Eats, Oranges))

-- First target is at index 0
local first = world:target(bob, Eats, 0)
print(first == Apples)  -- true

-- Second target is at index 1
local second = world:target(bob, Eats, 1)
print(second == Oranges)  -- true

-- No third target: index 2 returns nil
local third = world:target(bob, Eats, 2)
print(third == nil)  -- true

-- Omitting the index is the same as index 0
local default = world:target(bob, Eats)
print(default == Apples)  -- true

-- Iterates through all targets
for target in world:targets(bob, Eats) do
	print(target)
end
