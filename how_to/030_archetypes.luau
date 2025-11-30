local jecs = require("@jecs")
local world = jecs.world()


local Position = world:component() :: jecs.Id<vector>

--[[
	When an entity moves to a new archetype, several things happen:

	1. The entity is removed from the old archetype's entity list
	2. Component data is copied from old columns to new columns (if the component
	   exists in both archetypes)
	3. The entity is added to the new archetype's entity list
	4. The entity's record is updated to point to the new archetype
	5. The entity's row index is updated to its position in the new archetype

	This movement is what makes adding/removing components relatively expensive
	compared to just setting component values. But it's necessary to maintain
	the invariant that all entities in an archetype have exactly the same
	component set.
]]



-- When you create an entity, it starts with no components. All entities with
-- no components belong to the ROOT_ARCHETYPE.
-- This is the starting point for all entities.

local e1 = world:entity()
world:set(e1, Position, vector.create(10, 20, 30))

--[[
	Archetypes are the fundamental storage unit in an archetypal ECS.
	An archetype represents a unique combination of components.
	All entities with exactly the same set of components belong to the same archetype.

	When you add a component to an entity, the entity must move from its current
	archetype to a new archetype that includes the new component.
	This transition process includes several operations:

	1. The entity is removed from the old archetype's entity list
	2. Component data is copied from old columns to new columns (if the component
	   exists in both archetypes)
	3. The entity is added to the new archetype's entity list
	4. The entity's record is updated to point to the new archetype
	5. The entity's row index is updated to its position in the new archetype
	If that archetype
	doesn't exist yet, it must be created.

	When an Archetype is created, it performs several operations:

	1. Allocates a new archetype ID (increments max_archetype_id)
	2. Creates storage columns
	3. Registers the archetype
	4. Updates component records
	5. Propagates it to cached queries that needs to update its list of archetyps

	Archetypes are connected in a graph structure. Each archetype has edges that
	point to other archetypes you can reach by adding or removing components.

	For example:
	- ROOT_ARCHETYPE has an edge for Position -> [Position]
	- [Position] has an edge for Velocity -> [Position, Velocity]
	- [Position] has an edge (backwards) for Position -> ROOT_ARCHETYPE

	This graph is cached. When you add a component, the ECS first checks if
	there's already an edge from the current archetype for that component.
	If the edge exists, it uses the cached archetype.

	If an edge doesn't exist it will do the following operations:
	   a. Create a new component list: [Position, Velocity] (sorted)
	   b. Hash it to get the type string
	   c. Check if archetype exists (might have been created by another entity)
	   d. If not, create it
	   e. Cache the edge in both directions

	This caching is what makes archetype transitions fast. Instead of searching
	through all archetypes every time, you just follow the graph edges.

	The edge caching happens in both directions:
	- [Position] -> [Position, Velocity] (for adding Velocity)
	- [Position, Velocity] -> [Position] (for removing Velocity)

]]
