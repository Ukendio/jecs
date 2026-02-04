--[[
	Wildcards let you query relationships without specifying the exact target or
	relationship. jecs.Wildcard matches any entity in that slot.

	- pair(relation, jecs.Wildcard) matches that relationship with any target.
	- pair(jecs.Wildcard, target) matches any relationship with that target.

	Use world:target(entity, relation, index) to get the actual target when
	querying with a wildcard. The index is 0-based (see 042_target.luau).
]]

local jecs = require("@jecs")
local pair = jecs.pair
local world = jecs.world()

local Eats = world:component() :: jecs.Id<{ amount: number }>
local Likes = world:entity()
local Apples = world:entity()
local alice = world:entity()
local bob = world:entity()

world:add(bob, pair(Eats, Apples))
world:set(bob, pair(Eats, Apples), { amount = 1 })
world:add(bob, pair(Likes, alice))

-- world:has with wildcard
print(world:has(bob, pair(Eats, jecs.Wildcard)))  -- true

-- Query with wildcard: all entities that eat something
for entity in world:query(pair(Eats, jecs.Wildcard)) do
	local food = world:target(entity, Eats)
	print(`Entity {entity} eats {food}`)
end

-- Query with wildcard: all entities that like someone
for entity in world:query(pair(Likes, jecs.Wildcard)) do
	local target = world:target(entity, Likes)
	print(`Entity {entity} likes {target}`)
end

-- Multiple targets: index is 0-based. Iterate until nil.
local charlie = world:entity()
world:add(bob, pair(Likes, charlie))

for entity in world:query(pair(Likes, jecs.Wildcard)) do
	local nth = 0
	local target = world:target(entity, Likes, nth)
	while target do
		print(`Entity {entity} likes {target}`)
		nth += 1
		target = world:target(entity, Likes, nth)
	end
end

-- pair(jecs.Wildcard, target): all relationships that have this target
for entity in world:query(pair(jecs.Wildcard, alice)) do
	print(`Entity {entity} has some relationship with alice`)
end
