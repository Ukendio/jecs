local jecs = require("@jecs")

--[[
	Tags are components without data. They are used to mark or categorize entities
	without storing any associated values. Think of them as boolean flags that
	can be added or removed from entities.

	A tag takes zero bytes of storage per entity. More importantly,
	tags enable a different mental model. When you see a tag on an
	entity, you know it's just a marker and there's no data to read or write.

	Tags are entities that do not have the builtin jecs.Component trait which
	tells the ECS that this ID doesn't cannot store any data, it is just a marker.
]]

--[[
	There are two ways to create tags:

	1. Using jecs.tag() to preregister a tag entity which will be allocated when you create the world.
	2. Using world:entity() to create a regular entity id

	The first method is the "proper" way to create tags but it hinges upon that
	you do remember to create the world after declaring all of your
	components/tags. This is a good practice because it is harder to mess up the
	offset of your component range, ensuring a stable type id.

	More on this is discussed in 011_preregistering_components.luau
]]

local Dead = jecs.tag()

-- Creating the world after the components to ensure they get allocated.
local world = jecs.world()

--
-- Tags are added using world:add(entity, component).
-- You cannot use world:set() with tags
-- because tags don't store data.

local entity = world:entity()

world:add(entity, Dead) -- Adds the tag

print(world:has(entity, Dead)) -- true

-- Tags are removed using world:remove(entity, component)

world:remove(entity, Dead)

print(world:has(entity, Dead)) -- false
