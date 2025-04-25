local jecs = require("@jecs")

type Observer<T...> = {
	callback: (jecs.Entity) -> (),
	query: jecs.Query<T...>,
}

export type PatchedWorld = jecs.World & {
	added: (PatchedWorld, jecs.Id, (e: jecs.Entity, id: jecs.Id, value: any) -> ()) -> (),
	removed: (PatchedWorld, jecs.Id, (e: jecs.Entity, id: jecs.Id) -> ()) -> (),
	changed: (PatchedWorld, jecs.Id, (e: jecs.Entity, id: jecs.Id) -> ()) -> (),
	observer: (PatchedWorld, Observer<any>) -> (),
	monitor: (PatchedWorld, Observer<any>) -> (),
}

local function observers_new(world, description)
	local query = description.query
	local callback = description.callback
	local terms = query.filter_with :: { jecs.Id }
	if not terms then
		local ids = query.ids
		query.filter_with = ids
		terms = ids
	end

	local entity_index = world.entity_index :: any
	local function emplaced(entity: jecs.Entity)
		local r = jecs.entity_index_try_get_fast(
			entity_index, entity :: any)

		if not r then
			return
		end

		local archetype = r.archetype

		if jecs.query_match(query, archetype) then
			callback(entity)
		end
	end

	for _, term in terms do
		world:added(term, emplaced)
		world:changed(term, emplaced)
 	end
end

local function monitors_new(world, description)
	local query = description.query
	local callback = description.callback
	local terms = query.filter_with :: { jecs.Id }
	if not terms then
		local ids = query.ids
		query.filter_with = ids
		terms = ids
	end

	local entity_index = world.entity_index :: any
	local function emplaced(entity: jecs.Entity)
		local r = jecs.entity_index_try_get_fast(
			entity_index, entity :: any)

		if not r then
			return
		end

		local archetype = r.archetype

		if jecs.query_match(query, archetype) then
			callback(entity, jecs.OnAdd)
		end
	end

	local function removed(entity: jecs.Entity, component: jecs.Id)
		local r = jecs.entity_index_try_get_fast(
			entity_index, entity :: any)

		if not r then
			return
		end

		local archetype = r.archetype

		if jecs.query_match(query, archetype) then
			callback(entity, jecs.OnRemove)
		end
	end

	for _, term in terms do
		world:added(term, emplaced)
		world:removed(term, removed)
 	end
end

local function observers_add(world: jecs.World & { [string]: any }): PatchedWorld
	type Signal = { [jecs.Entity]: { (...any) -> () } }
	local signals = {
		added = {} :: Signal,
		emplaced = {} :: Signal,
		removed = {} :: Signal
	}

	world.added = function(_, component, fn)
		local listeners = signals.added[component]
		local max = #listeners + 1
		local component_index = world.component_index :: jecs.ComponentIndex
		assert(component_index[component] == nil, "You cannot use hooks on components you intend to use this signal with")
		if not listeners then
			listeners = {}
			signals.added[component] = listeners

			local function on_add(entity: number, id: number, value: any)
				for _, listener in listeners :: any do
					listener(entity, id, value)
				end
			end
			world:set(component, jecs.OnAdd, on_add)
		end
		listeners[max] = fn
		return function()
			local n = #listeners
			listeners[max] = listeners[n]
			listeners[n] = nil
		end
	end

	world.changed = function(_, component, fn)
		local listeners = signals.emplaced[component]
		local max = 0
		local component_index = world.component_index :: jecs.ComponentIndex
		assert(component_index[component] == nil, "You cannot use hooks on components you intend to use this signal with")
		if not listeners then
			listeners = {}
			max = 1
			signals.emplaced[component] = listeners
			local function on_change(entity: number, id: number, value: any)
				for _, listener in listeners :: any do
					listener(entity, id, value)
				end
			end
			world:set(component, jecs.OnChange, on_change)
		else
			max = #listeners + 1
		end
		listeners[max] = fn
		return function()
			local n = #listeners
			listeners[max] = listeners[n]
			listeners[n] = nil
		end
	end

	world.removed = function(_, component, fn)
		local listeners = signals.removed[component]
		local max = #listeners
		local component_index = world.component_index :: jecs.ComponentIndex
		assert(component_index[component] == nil, "You cannot use hooks on components you intend to use this signal with")
		if not listeners then
			listeners = {}
			signals.removed[component] = listeners
			local function on_remove(entity: number, id: number, value: any)
				for _, listener in listeners :: any do
					listener(entity, id, value)
				end
			end
			world:set(component, jecs.OnRemove, on_remove)
		end
		listeners[max] = fn
		return function()
			local n = #listeners
			listeners[max] = listeners[n]
			listeners[n] = nil
		end
	end

	world.signals = signals

	world.observer = observers_new

	world.monitor = monitors_new

	return world :: PatchedWorld
end

return observers_add
