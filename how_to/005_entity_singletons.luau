local jecs = require("@jecs")
local world = jecs.world()

-- Singletons are components for which only a single instance exists on the world.
-- They can be accessed on the world directly and do not require providing
-- an entity. Singletons are useful for global game resources, such as game state,
-- a handle to a physics engine or a network socket.

local TimeOfDay = world:component() :: jecs.Id<number>
world:set(TimeOfDay, TimeOfDay, 5)
local t = world:get(TimeOfDay, TimeOfDay)
print(`The time of day is {t}`)
