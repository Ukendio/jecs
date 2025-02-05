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

local Position = named(world.component, "Position") :: jecs.Entity<vector>
local Previous = jecs.Rest

local added = world
	:query(Position)
	:without(pair(Previous, Position))
	:cached()
local changed = world
	:query(Position, pair(Previous, Position))
	:cached()
local removed = world
	:query(pair(Previous, Position))
	:without(Position)
	:cached()


local e1 = named(world.entity, "e1")
world:set(e1, Position, vector.create(10, 20, 30))
local e2 = named(world.entity, "e2")
world:set(e2, Position, vector.create(10, 20, 30))
for entity, p in added do
	print(`Added {name(entity)}: \{{p.x}, {p.y}, {p.z}}`)
	world:set(entity, pair(Previous, Position), p)
end

world:set(e1, Position, vector.create(999, 999, 1998))

for _, archetype in changed:archetypes() do
	if new ~= old then
		print(`{name(e)}'s Position changed from \{{old.x}, {old.y}, {old.z}\} to \{{new.x}, {new.y}, {new.z}\}`)
		world:set(e, pair(Previous, Position), new)
	end
end

world:remove(e2, Position)

for e in removed:iter() do
	print(`Position was removed from {name(e)}`)
	world:remove(e, pair(Previous, Position))
end

-- Output:
--  Added 265: {10, 20, 30}
--  Added 264: {10, 20, 30}
--  e1's Position changed from {10, 20, 30} to {999, 999, 1998}
--  Position was removed from e2
