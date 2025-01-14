local jecs = require("@jecs")

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

local Position = named(world.component, "Position") :: jecs.Entity<Vector3>
local Previous = jecs.Rest
local PreviousPosition = jecs.pair(Previous, Position)

local added = world
	:query(Position)
	:without(PreviousPosition)
	:cached()
local changed = world
	:query(Position, PreviousPosition)
	:cached()
local removed = world
	:query(PreviousPosition)
	:without(Position)
	:cached()

local e1 = named(world.entity, "e1")
world:set(e1, Position, Vector3.new(10, 20, 30))

local e2 = named(world.entity, "e2")
world:set(e2, Position, Vector3.new(10, 20, 30))

for e, p in added:iter() do
	print(`Added {e}: \{{p.X}, {p.Y}, {p.Z}}`)
	world:set(e, PreviousPosition, p)
end

world:set(e1, Position, "")

for e, new, old in changed:iter() do
	if new ~= old then
		print(`{name(new)}'s Position changed from \{{old.X}, {old.Y}, {old.Z}\} to \{{new.X}, {new.Y}, {new.Z}\}`)
		world:set(e, PreviousPosition, new)
	end
end

world:remove(e2, Position)

for e in removed:iter() do
	print(`Position was removed from {name(e)}`)
end

-- Output:
--  Added 265: {10, 20, 30}
--  Added 264: {10, 20, 30}
--  e1's Position changed from {10, 20, 30} to {999, 999, 1998}
--  Position was removed from e2
