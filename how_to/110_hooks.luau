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

world:set(Transform, jecs.OnRemove, function(entity, id, delete)
	-- A transform component id has been removed from entity
	-- delete is true if the entity is being deleted, false/nil otherwise
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
]]

--[[
	Structural changes in OnRemove hooks

	You can call world:add, world:remove, and world:set inside OnRemove hooks.
	That's fine. But there's a catch.

	When an entity is being deleted, all of its components get removed. Each
	removal triggers the OnRemove hook. If you try to make structural changes
	to the entity during deletion, like removing more components or adding new
	ones, you're fighting against the deletion process itself. The entity is
	going to lose all its components anyway, so what's the point?

	This creates a conflict. On one hand, you might want to clean up related
	components when a specific component is removed. On the other hand, during
	deletion, you don't want to do that because the entity is already being
	torn down. So you need a way to tell the difference.

	The solution is the delete boolean. Every OnRemove hook receives it as the
	third parameter. It's true when the entity is being deleted, and false
	(or nil) when you're just removing a single component normally.

	So you check it. If delete is true, you bail out early. If it's false,
	you do your cleanup. Simple.

	Here's what it looks like in practice:
]]

local Health = world:component()
local Dead = world:component()

world:set(Health, jecs.OnRemove, function(entity, id, delete)
	if delete then
		-- Entity is being deleted, don't try to clean up
		return
	end

	-- Normal removal, do cleanup
	world:remove(entity, Dead)
end)

--[[
	The ob.luau module uses this pattern extensively. When you're building
	observers or monitors that track component removals, you need to distinguish
	between "component removed" and "entity deleted" because they mean different
	things for your tracking logic.

	Now, about the DEBUG flag. If you create a world with DEBUG enabled:

		local world = jecs.world(true)

	Then the world will actively prevent you from calling world:add, world:remove,
	or world:set inside OnRemove hooks when delete is true. It throws an error
	that tells you exactly what went wrong. This is useful during development
	to catch cases where you forgot to check the delete flag.

	But here's the important part: even with DEBUG enabled, you're still allowed
	to call these functions when delete is false. The DEBUG mode only prevents
	structural changes during deletion, not during normal component removal.

	So the pattern is always the same: check delete, bail if true, proceed if false.
	The DEBUG flag just makes sure you don't forget to do the check.
]]
