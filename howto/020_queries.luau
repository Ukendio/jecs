--[[
	Queries enable games to quickly find entities that satisfies provided conditions.
	In jecs, queries can do anything from returning entities that match a simple
	list of components, to matching against entity graphs.

	Some of the features of Jecs queries are:
	- Queries have support for relationships pairs which allow for matching against
	  entity graphs without having to build complex data structures for it.
	- Queries support filters such as query:with(...) if entities are required to
	  have the components but you don't actually care about components value.
	  And query:without(...) which selects entities without the components.
	- Queries can be drained or reset on when called, which lets you choose iterator behaviour.
	- Queries can be called with any ID, including entities created dynamically,
	  this is useful for pairs.
	- Queries are already fast but can be further inlined via query:archetypes()
	  for maximum performance to eliminate function call overhead which is roughly
	  60-80% of the cost for iteration.
]]

local jecs = require("@jecs")
local world = jecs.world()

local Position = world:component() :: jecs.Id<vector>
local Velocity = world:component() :: jecs.Id<vector>

for entity, pos, vel in world:query(Position, Velocity) do
	-- Process entities with both Position and Velocity
end

--[[
	A component is any single ID that can be added to an entity. This includes
	tags and regular entities, which are IDs that do not have the builtin Component
	component. To match a query, an entity must have all the requested components.
]]

local e1 = world:entity()
world:add(e1, Position)

local e2 = world:entity()
world:add(e2, Position)
world:add(e2, Velocity)

local e3 = world:entity()
world:add(e3, Position)
world:add(e3, Velocity)
local Mass = world:component()
world:add(e3, Mass)

-- Only entities e2 and e3 match the query Position, Velocity
for entity, pos, vel in world:query(Position, Velocity) do
	print(`Entity {entity} has Position and Velocity`)
end
