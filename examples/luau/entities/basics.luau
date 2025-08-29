local jecs = require("@jecs")
local world = jecs.world()

local Position = world:component() :: jecs.Id<vector>
local Walking = world:component()
local Name = world:component() :: jecs.Id<string>

local function name(e: jecs.Entity): string
	return assert(world:get(e, Name))
end

-- Create an entity with name Bob
local bob = world:entity()

-- The set operation finds or creates a component, and sets it.
world:set(bob, Position, vector.create(10, 20, 30))
-- Name the entity Bob
world:set(bob, Name, "Bob")
-- The add operation adds a component without setting a value. This is
-- useful for tags, or when adding a component with its default value.
world:add(bob, Walking)

-- Get the value for the Position component
local pos = world:get(bob, Position)
assert(pos)
print(`\{{pos.x}, {pos.y}, {pos.z}\}`)

-- Overwrite the value of the Position component
world:set(bob, Position, vector.create(40, 50, 60))

local alice = world:entity()
-- Create another named entity
world:set(alice, Name, "Alice")
world:set(alice, Position, vector.create(10, 20, 30))
world:add(alice, Walking)

-- Remove tag
world:remove(alice, Walking)

-- Iterate all entities with Position
for entity, p in world:query(Position) do
	print(`{name(entity)}: \{{p.x}, {p.y}, {p.z}\}`)
end

-- Output:
--  {10, 20, 30}
--  Alice: {10, 20, 30}
--  Bob: {40, 50, 60}
