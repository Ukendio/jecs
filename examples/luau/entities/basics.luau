local jecs = require("@jecs")
local world = jecs.World.new()

local Position = world:component()
local Walking = world:component()
local Name = world:component()

-- Create an entity with name Bob
local bob = world:entity()

-- The set operation finds or creates a component, and sets it.
world:set(bob, Position, Vector3.new(10, 20, 30))
-- Name the entity Bob
world:set(bob, Name, "Bob")
-- The add operation adds a component without setting a value. This is
-- useful for tags, or when adding a component with its default value.
world:add(bob, Walking)

-- Get the value for the Position component
local pos = world:get(bob, Position)
print(`\{{pos.X}, {pos.Y}, {pos.Z}\}`)

-- Overwrite the value of the Position component
world:set(bob, Position, Vector3.new(40, 50, 60))


local alice = world:entity()
-- Create another named entity
world:set(alice, Name, "Alice")
world:set(alice, Position, Vector3.new(10, 20, 30))
world:add(alice, Walking)


-- Remove tag
world:remove(alice, Walking)

-- Iterate all entities with Position
for entity, p in world:query(Position) do
    print(`{entity}: \{{p.X}, {p.Y}, {p.Z}\}`)
end

-- Output:
--  {10, 20, 30}
--  Alice: {10, 20, 30}
--  Bob: {40, 50, 60}
