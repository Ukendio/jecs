local jecs = require("@jecs")
local world = jecs.world()

--[[
	In an ECS, components need to be uniquely identified. In Jecs this is done
	by making each component its own unique entity.

	If a game has a component Position and Velocity, there will be two entities,
	one for each component. Component entities can be distinguished from "regular"
	entities as they have a Component component trait.

	This might seem odd at first. Why make components entities? The answer
	is uniformity. If components are entities, then all the APIs that work
	on entities also work on components. You can set metadata on components,
	you can query for components, you can create relationships between components.
	Everything is just entities, and entities can have components, so components
	can have components too.
]]


local Position = world:component() :: jecs.Id<vector>
world:set(Position, jecs.Name, "Position") -- Using regular APIs to set metadata on component entities!

print(`{world:get(Position, jecs.Name)} is a Component: {world:has(Position, jecs.Component)}`)

-- Component IDs occupy the range 1-256.

-- This partitioning comes at a cost, you can only linearize the component IDs
-- up to 256. This is usually sufficient.

-- Otherwise you must either patch jecs itself to increment the "HI_COMPONENT_ID"
-- or create your own entities and then add the jecs.Component trait.

local high_comp_id = world:entity()
world:add(high_comp_id, jecs.Component)
