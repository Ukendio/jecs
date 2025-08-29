-- Using world:target is the recommended way to grab the target in a wildcard
-- query. However the random access can add up in very hot paths. Accessing its
-- column can drastically improve performance, especially when there are
-- multiple adjacent pairs.

local jecs = require("@jecs")
local pair = jecs.pair
local __ = jecs.Wildcard

local world = jecs.world()

local Likes = world:entity()
local function name(e, name: string): string
	if name then
		world:set(e, jecs.Name, name)
		return name
	end
	return assert(world:get(e, jecs.Name))
end

local e1 = world:entity()
name(e1, "e1")
local e2 = world:entity()
name(e2, "e2")
local e3 = world:entity()
name(e3, "e3")

world:add(e1, pair(Likes, e2))
world:add(e1, pair(Likes, e3))

local likes = jecs.component_record(world, pair(Likes, __))
assert(likes)

local likes_cr = likes.records
local likes_counts = likes.counts

local archetypes = world:query(pair(Likes, __)):archetypes()

for _, archetype in archetypes do
	local types = archetype.types

	-- Get the starting index which is what the (R, *) alias is at
	local wc = likes_cr[archetype.id]
	local count = likes_counts[archetype.id]

	local entities = archetype.entities
	for i = #entities, 1, -1 do
		-- It is generally a good idea to iterate backwards on arrays if you
		-- need to delete the iterated entity to prevent iterator invalidation
		local entity = entities[i]
		for cr = wc, wc + count - 1 do
			local person = jecs.pair_second(world, types[cr])
			print(`entity ${entity} likes ${person}`)
		end
	end
end

-- Output:
--  entity $273 likes $275
--  entity $273 likes $274
