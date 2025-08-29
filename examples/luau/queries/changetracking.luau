local jecs = require("@jecs")
local pair = jecs.pair

local world = jecs.world()
local Name = world:component() :: jecs.Id<string>


local function name(e: jecs.Entity): string
	return assert(world:get(e, Name))
end

local Position = world:component() :: jecs.Id<vector>
world:set(Position, Name, "Position")
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


local e1 = world:entity()
world:set(e1, Name, "e1")
world:set(e1, Position, vector.create(10, 20, 30))

local e2 = world:entity()
world:set(e2, Name, "e2")
world:set(e2, Position, vector.create(10, 20, 30))

for entity, p in added do
	print(`Added {name(entity)}: \{{p.x}, {p.y}, {p.z}}`)
	world:set(entity, pair(Previous, Position), p)
end

world:set(e1, Position, vector.create(999, 999, 1998))

for entity, new, old in changed do
	if new ~= old then
		print(`{name(entity)}'s Position changed from \{{old.x}, {old.y}, {old.z}\} to \{{new.x}, {new.y}, {new.z}\}`)
		world:set(entity, pair(Previous, Position), new)
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
