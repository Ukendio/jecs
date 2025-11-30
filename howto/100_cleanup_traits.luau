local jecs = require("@jecs")
local pair = jecs.pair
local world = jecs.world()

local T1 = world:entity()
local T2 = world:entity()

--[[
	When entities that are used as tags, components, relationships or relationship
	targets are deleted, cleanup traits ensure that the store does not contain any
	dangling references. Any cleanup policy provides this guarantee, so while they
	are configurable, games cannot configure traits that allows for dangling references.

	We also want to specify this per relationship. If an entity has (Likes, parent)
	we may not want to delete that entity, meaning the cleanup we want to perform
	for Likes and ChildOf may not be the same.

	This is what cleanup traits are for: to specify which action needs to be executed
	under which condition. They are applied to entities that have a reference to
	the entity being deleted: if I delete the Archer tag I remove the tag from all
	entities that have it.

	To configure a cleanup policy for an entity, a (Condition, Action) pair can
	be added to it. If no policy is specified, the default cleanup action (Remove)
	is performed.

	Cleanup Actions:
	- Remove: removes instances of the specified (component) id from all entities (default)
	- Delete: deletes all entities with specified id

	Cleanup Conditions:
	- OnDelete: the component, tag or relationship is deleted
	- OnDeleteTarget: a target used with the relationship is deleted
]]


--[[
	(OnDelete, Remove)
	Removes the component from all entities when the component is deleted.
	Default behavior, safe cleanup.
--]]

world:add(T1, pair(jecs.OnDelete, jecs.Remove))

local e1 = world:entity()
world:add(e1, T1)

-- This will remove T1 from e
world:delete(T1)
print(world:has(e1, T1))

--[[
	When an ID added to an entity is deleted, all references to that ID are deleted
	from the storage. For example, when the component Position is deleted it is
	removed from all entities, and all archetypes with the Position component are
	deleted. While not unique to relationships, it is more common for relationships
	to trigger cleanup actions, as relationship pairs contain regular entities.

	The opposite is also true. Because relationship pairs can contain regular entities
	which can be created on the fly, archetype creation is more common than in games
	that do not use relationships. While Jecs is optimized for fast archetypes creation,
	creating and cleaning up archetypes is inherently more expensive than creating/deleting
	an entity. Therefore archetypes creation is a factor to consider, especially for
	games that make extensive use of relationships.
--]]


--[[
	(OnDelete, Delete)
	Deletes all entities that have the component when the component is deleted.
	Cascading deletion, dangerous.
]]

world:add(T2, pair(jecs.OnDelete, jecs.Remove))

local e2 = world:entity()
world:add(e2, T2)

-- This will delete e along with T2
world:delete(T2)
print(`Is Entity still in the World {world:contains(e2)}`)
print(`Is T2 still in the World {world:contains(T2)}`)


--[[
	(OnDeleteTarget, Remove)
	Removes the relationship from all entities when the target is deleted.
	Safe relationship cleanup.
]]

local OwnedBy = world:component()
world:add(OwnedBy, pair(jecs.OnDeleteTarget, jecs.Remove))

local loot = world:entity()
local player = world:entity()
world:add(loot, pair(OwnedBy, player))

-- This will remove (OwnedBy, player) from loot
world:delete(player)

print(`Is the loot still owned by the player {world:contains(loot)}`)


--[[
	(OnDeleteTarget, Delete)
	Deletes all entities that have the relationship when the target is deleted.
	Hierarchical deletion (e.g., parent-child).
]]

-- ChildOf actually exists as apart of jecs' builtin IDs but we demonstrate
-- how it works here:
local ChildOf = world:component()
world:add(ChildOf, pair(jecs.OnDeleteTarget, jecs.Delete))

local parent = world:entity()
local child = world:entity()
world:add(child, pair(ChildOf, parent))

-- This will delete both parent and child
world:delete(parent)

print(`Is parent still in the World {world:contains(parent)}`)
print(`Is child still in the World {world:contains(child)}`)
