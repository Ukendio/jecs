-- To get the most out of performance, you can lift the inner loop of queries to
-- the system in which you can do archetype-specific optimizations like finding
-- the parent once per archetype rather than per entity.

local jecs = require("@jecs")
local pair = jecs.pair
local ChildOf = jecs.ChildOf
local __ = jecs.Wildcard

local world = jecs.world()

local Position = world:component() :: jecs.Id<vector>
local Visible = world:entity()

local parent = world:entity()
world:set(parent, Position, vector.zero)
world:add(parent, Visible)

local child = world:entity()
world:set(child, Position, vector.one)
world:add(child, pair(ChildOf, parent))

local parents = jecs.component_record(world, pair(ChildOf, __))
assert(parents)

local parent_cr = parents.records

local archetypes = world:query(Position, pair(ChildOf, __)):archetypes()

for _, archetype in archetypes do
	local types = archetype.types
	local p = jecs.pair_second(world, types[parent_cr[archetype.id]])
	if world:has(p, Visible) then
		local columns = archetype.columns_map
		local positions = columns[Position]
	  	for row, entity in archetype.entities do
			local pos = positions[row]
			print(`Child ${entity} of ${p} is visible at {pos}`)
		end
	end
end

-- Output:
--  Child $274 of $273 is visibile at 1,1,1
