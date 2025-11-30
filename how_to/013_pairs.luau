local jecs = require("@jecs")
local pair = jecs.pair
local world = jecs.world()

local pair_first = jecs.pair_first
local pair_second = jecs.pair_second
local is_pair = jecs.IS_PAIR

local Likes = world:entity()
local Owns = world:component() :: jecs.Id<{ purchase_date: string }>
local alice = world:entity()
local car = world:entity()

--[[
	A pair is an ID that encodes two elements. Pairs, like components, can be
	added to entities and are the foundation for Relationships.

	The elements of a pair are allowed to be wildcards. When a query pair returns
	an Any type wildcard, the query returns at most a single matching pair on
	an entity.

	Pairs encode two entity IDs into a single 53-bit ID. This encoding allows
	the ECS to treat pairs the same way as regular component IDs at the storage
	level, while still being able to decode them back into their constituent
	parts when needed.

	The pair encoding uses the upper bits of the 53-bit ID space. Specifically,
	pairs have an offset (ECS_PAIR_OFFSET = 2^48) added to them, which makes
	them larger than any possible regular entity ID. This allows the ECS to
	quickly distinguish pairs from regular entities by checking if the ID is
	greater than the pair offset.
]]


--[[
	Creating pairs

	You create a pair using the pair() function. It takes two entities:
	- The first entity is the relationship/predicate (e.g., "Likes", "Owns")
	- The second entity is the target/object (e.g., "alice", "car")
]]

local likes_alice_pair = pair(Likes, alice)
print(`Pair ID: {likes_alice_pair}`)

local owns_car_pair = pair(Owns, car)
print(`Pair ID: {owns_car_pair}`)

local entity = world:entity()

-- Pairs can be used just like component IDs. You can add them to entities,
-- query for them, and store data with them.
world:add(entity, pair(Likes, alice))
print(`entity likes alice {world:has(entity, pair(Likes, alice))}`)

world:set(entity, pair(Owns, car), { purchase_date = "2024-01-01" })

local ownership_data = world:get(entity, pair(Owns, car))
assert(ownership_data)
print(`Ownership data: {ownership_data.purchase_date}`)

-- You can check if an ID is a pair using jecs.IS_PAIR(). This is useful
-- when you're working with IDs and need to know if they're pairs or
-- regular entities.

local regular_id = world:entity()
local pair_id = pair(Likes, alice)

print(is_pair(regular_id))
print(is_pair(pair_id))

-- If you have a pair ID, you can extract the first and second elements
-- using jecs.ECS_PAIR_FIRST() and jecs.ECS_PAIR_SECOND(). However, these
-- return the raw entity IDs, so you typically want to use world:target()
-- instead, which handles alive entity resolution.


local p = pair(Likes, alice)
local first = pair_first(world, p)
local second = pair_second(world, p)

print(`Pair ({first}, {second})`)

-- Pairs can have components as targets, not just entities. This is useful
-- for relationships like "has Position at (0, 0, 0)" or "has Health of 100".

-- However, this is less common. Typically, you use pairs for entity-to-entity
-- relationships, and regular components for entity-to-data relationships.

local Position = world:component() :: jecs.Id<vector>
local Begin = world:entity()
local End = world:entity()
world:set(entity, pair(Begin, Position), vector.create(0, 0, 0))
world:set(entity, pair(End, Position), vector.create(10, 20, 30))
