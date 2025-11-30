local jecs = require("@jecs")
local world = jecs.world()

--[[
	A component is something that is added to an entity. Components can simply
	tag an entity ("this entity is an Npc"), attach data to an entity ("this entity
	is at Position Vector3.new(10, 20, 30)") and create relationships between
	entities ("bob Likes alice") that may also contain data ("bob Eats 10 apples").
]]

-- Create a component with a type
local Position = world:component() :: jecs.Id<vector>
local Health = world:component() :: jecs.Id<number>

--[[
	Components are keys to ECS storage columns. Think of the ECS storage as
	a table where:
	- Rows are entities
	- Columns are components
	- Cells are the component data for that entity

	When you create a component, you're creating a key that you'll use to
	index into the storage. The component ID is what tells the ECS "I want
	to access the Position column" or "I want to access the Health column".

	The component ID is just a number, but it's been registered with the world.
	This registration is what allows the ECS to know about the component and
	allocate storage for it when entities use it.
]]

print(`Position component ID: {Position}`)
print(`Health component ID: {Health}`)

--[[
	If you try to use a number as a component ID that has not been registered,
	the ECS will throw an error at runtime because the ID is not known to the
	World. You must create components using world:component() before you can
	use them.
]]

local entity = world:entity()

--[[
	world:set(entity, component, value)

	Sets the value of a component for an entity. This is how you store data
	in the ECS columns. The component ID acts as the column index, and the
	entity acts as the row index.

	If the entity doesn't already have the component, set() will add it
	automatically. If it does have the component, set() will update the
	existing value.

	The type system enforces that the value you provide matches the component's
	type. This prevents type errors at compile time (if using a type checker).
]]

-- Set initial values
world:set(entity, Position, vector.create(10, 20, 30))
world:set(entity, Health, 100)

-- Update values (set works for both adding and updating)
world:set(entity, Position, vector.create(40, 50, 60))
world:set(entity, Health, 50)

--[[
	world:get(entity, component)

	Retrieves the value of a component from an entity. This is how you read
	data from the ECS columns. The component ID tells the ECS which column
	to look in, and the entity tells it which row.

	The return type is `T?` (T or nil), not just `T`. This is because the
	entity might not have the component, or the entity might have been deleted.
	You should always handle the nil case.

	In practice, you'll often use assert() if you know the component should
	exist, or check for nil if it might not exist.
]]

-- Get component values
local pos = world:get(entity, Position)
local health = world:get(entity, Health)

print(`Entity position: {pos}`)
print(`Entity health: {health}`)

-- Handle the nil case
local maybe_pos = world:get(entity, Position)
if maybe_pos then
	print(`Position exists: {maybe_pos}`)
else
	print("Entity doesn't have Position")
end

-- Or use assert if you know it should exist
local pos_assert = assert(world:get(entity, Position))
print(`Position (asserted): {pos_assert}`)

--[[
	world:remove(entity, component)

	Removes a component from an entity. This removes the data from the storage
	column for that entity. The entity will no longer have that component.

	If the entity doesn't have the component, remove() does nothing (it's
	idempotent). This makes it safe to call remove() multiple times.

	Note: remove() only removes the component, it doesn't delete the entity.
	Use world:delete() if you want to delete the entire entity.
]]

-- Remove a component
world:remove(entity, Health)

-- Now Health is gone
print(`Health after remove: {world:get(entity, Health)}`)  -- nil

-- Position is still there
print(`Position after removing Health: {world:get(entity, Position)}`)  -- still has value

-- Removing a component that doesn't exist does nothing
world:remove(entity, Health)  -- Safe to call again, does nothing

--[[
	Components are keys to storage columns. When you use set(), get(), or remove(),
	you're using the component ID to index into the ECS storage:

	set(entity, Position, value)  ->  storage[Position][entity] = value
	get(entity, Position)         ->  return storage[Position][entity]
	remove(entity, Position)      ->  storage[Position][entity] = nil

	This is the fundamental abstraction of the ECS: components are column keys,
	entities are row keys, and the storage is a two-dimensional table.

	In reality, the storage is more sophisticated (it uses archetypes for
	efficiency), but this mental model is useful for understanding how the
	APIs work.
]]
