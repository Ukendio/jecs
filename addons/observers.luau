local jecs = require("@jecs")

type Observer = {
	callback: (jecs.Entity) -> (),
	query: jecs.Query<...jecs.Id>,
}

export type PatchedWorld = jecs.World & {
	added: <T>(PatchedWorld, jecs.Id<T>, (jecs.Entity, jecs.Id, T) -> ()) -> () -> (),
	removed: <T>(PatchedWorld, jecs.Id<T>, (jecs.Entity, jecs.Id) -> ()) -> () -> (),
	changed: <T>(PatchedWorld, jecs.Id<T>, (jecs.Entity, jecs.Id, T) -> ()) -> () -> (),
	observer: (PatchedWorld, Observer) -> (),
	monitor: (PatchedWorld, Observer) -> (),
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
	local function emplaced(entity, id, value)
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


local function join(world, component)
	local sparse_array = {}
	local dense_array = {}
	local values = {}
	local max_id = 0

	world:added(component, function(entity, id, value)
		max_id += 1
		sparse_array[entity] = max_id
		dense_array[max_id] = entity
		values[max_id] = value
	end)

	world:removed(component, function(entity, id)
		local e_swap = dense_array[max_id]
		local v_swap = values[max_id]

		local dense = sparse_array[entity]
		dense_array[dense] = e_swap
		values[dense] = v_swap

		sparse_array[entity] = nil
		dense_array[max_id] = nil
		values[max_id] = nil
		max_id -= 1
	end)

	world:changed(component, function(entity, id, value)
		values[sparse_array[entity]] = value
	end)

	return function()
		local i = max_id
		return function(): ...any
			i -= 1
			if i == 0 then
				return nil
			end
			local e = dense_array[i]
			return e, values[i]
		end
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

local function observers_add(world: jecs.World): PatchedWorld
	type Signal = { [jecs.Entity]: { (...any) -> () } }

	local world_mut = world :: jecs.World & {[string]: any}

	local signals = {
		added = {} :: Signal,
		emplaced = {} :: Signal,
		removed = {} :: Signal
	}

	world_mut.added = function<T>(
		_: jecs.World,
		component: jecs.Id<T>,
		fn: (e: jecs.Entity, id: jecs.Id, value: T) -> ()
	)
		local listeners = signals.added[component]
		if not listeners then
			listeners = {}
			signals.added[component] = listeners

			local function on_add(entity: number, id: number, value: any)
				for _, listener in listeners :: any do
					listener(entity, id, value)
				end
			end
			local idr = world.component_index[component]
			if idr then
				local idr_hook_existing = idr.hooks.on_add
				if idr_hook_existing then
					table.insert(listeners, idr_hook_existing)
				end
				idr.hooks.on_add = on_add :: any
			else
				world:set(component, jecs.OnAdd, on_add)
			end
		end
		table.insert(listeners, fn)
		return function()
			local n = #listeners
			local i = table.find(listeners, fn)
			listeners[i] = listeners[n]
			listeners[n] = nil
		end
	end

	world_mut.changed = function<T>(
		_: jecs.World,
		component: jecs.Id<T>,
		fn: (e: jecs.Entity, id: jecs.Id, value: T) -> ()
	)
		local listeners = signals.emplaced[component]
		if not listeners then
			listeners = {}
			signals.emplaced[component] = listeners
			local function on_change(entity: number, id: number, value: any)
				for _, listener in listeners :: any do
					listener(entity, id, value)
				end
			end
			local idr = world.component_index[component]
			if idr then
				local idr_hook_existing = idr.hooks.on_change
				if idr_hook_existing then
					table.insert(listeners, idr_hook_existing)
				end
				idr.hooks.on_change = on_change :: any
			else
				world:set(component, jecs.OnChange, on_change)
			end
		end
		table.insert(listeners, fn)
		return function()
			local n = #listeners
			local i = table.find(listeners, fn)
			listeners[i] = listeners[n]
			listeners[n] = nil
		end
	end

	world_mut.removed = function<T>(
		_: jecs.World,
		component: jecs.Id<T>,
		fn: (e: jecs.Entity, id: jecs.Id) -> ()
	)
		local listeners = signals.removed[component]
		if not listeners then
			listeners = {}
			signals.removed[component] = listeners
			local function on_remove(entity: number, id: number, value: any)
				for _, listener in listeners :: any do
					listener(entity, id, value)
				end
			end
			local idr = world.component_index[component]
			if idr then
				local idr_hook_existing = idr.hooks.on_remove
				if idr_hook_existing then
					table.insert(listeners, idr_hook_existing)
				end
				idr.hooks.on_remove = on_remove :: any
			else
				world:set(component, jecs.OnRemove, on_remove)
			end
		end
		table.insert(listeners, fn)
		return function()
			local n = #listeners
			local i = table.find(listeners, fn)
			listeners[i] = listeners[n]
			listeners[n] = nil
		end
	end

	world_mut.signals = signals

	world_mut.observer = observers_new

	world_mut.monitor = monitors_new

	world_mut.trackers = {}

	return world_mut :: PatchedWorld
end

return observers_add
