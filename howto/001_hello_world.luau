--[[
	It all has to start somewhere. A world stores entities and their components,
	and manages them. This tour will reference it for every operation.
]]

local jecs = require("@jecs")
local world = jecs.world()

--[[
	You can declare component ids with specific types with this format:

	ComponentId = world:component() :: jecs.Id<Type>
]]

local Position = world:component() :: jecs.Id<vector>

-- Creates an empty entity and returns its handle
local entity = world:entity()

-- You can give entities data using `world:set()`. The type solver will
-- enforce that the data you assign to the entity will match the type
-- of the component id.
world:set(entity, Position, vector.create(1, 2, 3))

-- If you want the Entity's Position, you can look it up with the component ID.
-- It will return the value with the component's type coalesced with "nil"
-- because the entity's type is only known at runtime.
print(`Entity's Position is {world:get(entity, Position)}`)

--[[
	To run it:
		luau 001_hello_world.luau
]]
