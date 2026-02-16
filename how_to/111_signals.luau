--[[
	Signals let you subscribe to component add, change, and remove events with
	multiple listeners per component. Unlike hooks (see 110_hooks.luau), which
	allow only one OnAdd, OnChange, and OnRemove per component, signals support
	any number of subscribers and each subscription returns an unsubscribe
	function so you can clean up when you no longer need to listen.

	Use signals when you need several independent systems to react to the same
	component lifecycle events, or when you want to subscribe and unsubscribe
	dynamically (e.g. a UI that only cares while it's mounted).
]]

local jecs = require("@jecs")
local world = jecs.world()

local Position = world:component() :: jecs.Id<{ x: number, y: number }>

--[[
	world:added(component, fn)

	Subscribe to "component added" events. Your callback is invoked with:
	(entity, id, value, oldarchetype) whenever the component is added to an entity.

	Returns a function; call it to unsubscribe.
]]

local unsub_added = world:added(Position, function(entity, id, value, oldarchetype)
	print(`Position added to entity {entity}: ({value.x}, {value.y})`)
end)

--[[
	world:changed(component, fn)

	Subscribe to "component changed" events. Your callback is invoked with:
	(entity, id, value, oldarchetype) whenever the component's value is updated
	on an entity (e.g. via world:set).

	Returns a function; call it to unsubscribe.
]]

local unsub_changed = world:changed(Position, function(entity, id, value, oldarchetype)
	print(`Position changed on entity {entity}: ({value.x}, {value.y})`)
end)

--[[
	world:removed(component, fn)

	Subscribe to "component removed" events. Your callback is invoked with:
	(entity, id, delete?) when the component is removed. The third argument
	`delete` is true when the entity is being deleted, false or nil when
	only the component was removed (same semantics as OnRemove in 110_hooks).

	Returns a function; call it to unsubscribe.
]]

local unsub_removed = world:removed(Position, function(entity, id, delete)
	if delete then
		print(`Entity {entity} deleted (had Position)`)
	else
		print(`Position removed from entity {entity}`)
	end
end)

local e = world:entity()
world:set(e, Position, { x = 10, y = 20 })   -- added
world:set(e, Position, { x = 30, y = 40 })   -- changed
world:remove(e, Position)                     -- removed

world:added(Position, function(entity)
	print("Second listener: Position added")
end)

world:set(e, Position, { x = 0, y = 0 }) -- Multiple listeners are all invoked

-- Unsubscribe when you no longer need to listen
unsub_added()
unsub_changed()
unsub_removed()

world:set(e, Position, { x = 1, y = 1 })
world:remove(e, Position)
