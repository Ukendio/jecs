--[[
	Relationships makes it possible to describe entity graphs natively in ECS.

	Adding/removing relationships is similar to adding/removing regular components,
	with as difference that instead of a single component id, a relationship adds
	a pair of two things to an entity. In this pair, the first element represents
	the relationship (e.g. "Eats"), and the second element represents the relationship
	target (e.g. "Apples").

	Relationships can be used to describe many things, from hierarchies to inventory
	systems to trade relationships between players in a game.

	Definitions:
	- Id: An id that can be added and removed
	- Component: Id with a single element (same as an entity id)
	- Relationship: Used to refer to first element of a pair
	- Target: Used to refer to second element of a pair
	- Source: Entity to which an id is added
]]

local jecs = require("@jecs")
local pair = jecs.pair
local world = jecs.world()

local Eats = world:component() :: jecs.Id<{ amount: number }>
local Likes = world:component()
local Apples = world:entity()
local bob = world:entity()
local alice = world:entity()

-- Add relationships
world:add(bob, pair(Eats, Apples))
world:add(bob, pair(Likes, alice))
world:add(alice, pair(Likes, bob))

-- Test if entity has a relationship pair
print(world:has(bob, pair(Eats, Apples)))  -- true

-- Test if entity has a relationship wildcard
print(world:has(bob, pair(Eats, jecs.Wildcard)))  -- true

--[[
	Querying for relationship targets

	One of the most common operations with relationships is finding all entities
	that have a relationship with a specific target. For example, finding all
	children of a parent, or finding all entities that like a specific person.
]]

-- Find all entities with a specific pair (all entities that eat apples)
for entity in world:query(pair(Eats, Apples)) do
	print(`Entity {entity} eats apples`)
end

-- Find all entities that like alice
for entity in world:query(pair(Likes, alice)) do
	print(`Entity {entity} likes alice`)
end

--[[
	Querying for children of a parent

	The built-in ChildOf relationship is commonly used for hierarchies. You can
	query for all children of a specific parent entity.
]]

local ChildOf = jecs.ChildOf
local parent = world:entity()
local child1 = world:entity()
local child2 = world:entity()

world:add(child1, pair(ChildOf, parent))
world:add(child2, pair(ChildOf, parent))

-- Find all children of a specific parent
for child in world:query(pair(ChildOf, parent)) do
	print(`Entity {child} is a child of parent {parent}`)
end

--[[
	Querying with wildcards and getting targets

	When you query with a wildcard, you can use world:target() to get the
	actual target entity. This is useful when you want to find all entities
	with a relationship, regardless of the target.
]]

-- Find all entities that eat something (any target)
for entity in world:query(pair(Eats, jecs.Wildcard)) do
	local food = world:target(entity, Eats)  -- Get the actual target
	print(`Entity {entity} eats {food}`)
end

-- Find all entities that like someone (any target)
for entity in world:query(pair(Likes, jecs.Wildcard)) do
	local target = world:target(entity, Likes)
	print(`Entity {entity} likes {target}`)
end

--[[
	Combining relationship queries with regular components

	You can combine relationship queries with regular component queries. This
	allows you to find entities that have both a relationship and regular
	components.
]]

local Position = world:component() :: jecs.Id<vector>
local Health = world:component() :: jecs.Id<number>

local player = world:entity()
world:set(player, Position, vector.create(10, 20, 30))
world:set(player, Health, 100)
world:add(player, pair(ChildOf, parent))

-- Find all children of parent that have Position and Health
for entity, pos, health in world:query(Position, Health, pair(ChildOf, parent)) do
	print(`Child {entity} has position {pos} and health {health}`)
end

--[[
	Querying for entities with multiple relationship targets

	An entity can have multiple relationships with the same relationship type
	but different targets. For example, bob might like both alice and charlie.

	When querying with a wildcard, you'll get the entity once, but world:target()
	will return the first matching target. If you need all targets, you'll need
	to use a different approach (see the targets example for advanced usage).
]]

local charlie = world:entity()
world:add(bob, pair(Likes, charlie))

-- This query will return bob once, even though bob likes both alice and charlie
for entity in world:query(pair(Likes, jecs.Wildcard)) do
	local target = world:target(entity, Likes)
	print(`Entity {entity} likes {target}`)  -- Will show one target per entity
end

--[[
	Querying for all relationships with a specific target

	You can also query for all entities that have any relationship with a
	specific target using a wildcard for the relationship part.
]]

-- Find all entities that have any relationship with alice as the target
for entity in world:query(pair(jecs.Wildcard, alice)) do
	-- Note: This is less common and may have performance implications
	print(`Entity {entity} has some relationship with alice`)
end

--[[
	Relationship pairs, just like regular component, can be associated with data.
]]

local Begin = world:entity()
local End = world:entity()

local e = world:entity()
world:set(e, pair(Eats, Apples), { amount = 1 })

world:set(e, pair(Begin, Position), vector.create(0, 0, 0))
world:set(e, pair(End, Position), vector.create(10, 20, 30))

world:add(e, pair(jecs.ChildOf, Position))

--[[
	Querying relationship pairs with data

	When you query for relationship pairs that have data, you can access that
	data just like regular components.
]]

-- Query for entities with Eats relationship and get the data
for entity, eats_data in world:query(pair(Eats, Apples)) do
	print(`Entity {entity} eats apples: amount = {eats_data.amount}`)
end

--[[
	When querying for relationship pairs, it is often useful to be able to find
	all instances for a given relationship or target. To accomplish this, a game
	can use wildcard expressions.

	Wildcards may used for the relationship or target part of a pair:

	pair(Likes, jecs.Wildcard) -- Matches all Likes relationships
	pair(jecs.Wildcard, Alice) -- Matches all relationships with Alice as target

	Using world:target() is the recommended way to get the target in a wildcard
	query. However, if you're in a very hot path and need maximum performance,
	you can access the relationship column directly (see advanced examples).
]]

for entity in world:query(pair(Eats, jecs.Wildcard)) do
	local nth = 0
	local food = world:target(entity, Eats, nth)
	while food do
		local eats_data = world:get(entity, pair(Eats, food))
		assert(eats_data) -- This coerces the type to be non-nilable for the type checker
		print(`Entity {entity} eats {food}: amount = {eats_data.amount}`)

		nth += 1
		food = world:target(entity, Eats, nth)
	end
end
