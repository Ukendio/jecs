--[[
	Component data generally need to adhere to a specific interface, and sometimes
	requires side effects to run upon certain lifetime cycles. In jecs, there are
	hooks which are component traits, that can define the behaviour of a component
	and enforce invariants, but can only be invoked through mutations on the
	component data. You can only configure a single OnAdd, OnRemove and OnChange
	hook per component, just like you can only have a single constructor and destructor.
]]

local jecs = require("@jecs")
local world = jecs.world()

local Transform = world:component()

world:set(Transform, jecs.OnAdd, function(entity, id, data)
	-- A transform component id has been added with data to entity
	print(`Transform added to entity {entity}`)
end)

world:set(Transform, jecs.OnRemove, function(entity, id)
	-- A transform component id has been removed from entity
	print(`Transform removed from entity {entity}`)
end)

world:set(Transform, jecs.OnChange, function(entity, id, data)
	-- A transform component id has been changed to data on entity
	print(`Transform changed on entity {entity}`)
end)

--[[
	Children are cleaned up before parents
	When a parent and its children are deleted, OnRemove hooks will be invoked
	for children first, under the condition that there are no cycles in the
	relationship graph of the deleted entities. This order is maintained for any
	relationship that has the (OnDeleteTarget, Delete) trait (see Component Traits
	for more details).

	When an entity graph contains cycles, order is undefined. This includes cycles
	that can be formed using different relationships.

	However an important note to make is that structural changes are not
	necessarily always safe in OnRemove hooks. For instance, when an entity is
	being deleted and invokes all of the OnRemove hooks on its components. It
	can cause a lot of issues with moving entities
]]
