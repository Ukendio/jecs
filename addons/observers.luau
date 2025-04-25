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

local function query_changed(world, component)
	assert(jecs.IS_PAIR(component) == false)
	local callerid = debug.info(2, "sl")

	local tracker = world.trackers[callerid]
	if not tracker then
		local records = {}
		local connections = {}
		tracker = {
			records = records,
			connections = connections
		}
		world.trackers[callerid] = tracker

		table.insert(connections, world:added(component, function(entity, id, v)
			tracker[entity] = {
				new = v
			}
		end))
		table.insert(connections, world:changed(component, function(entity, id, v)
			local record = tracker[entity]
			record.old = record.new
			record.new = v
		end))

		table.insert(connections, world:removed(component, function(entity, id)
			local record = tracker[entity]
			record.old = record.new
			record.new = nil
		end))
	end

	local entity = nil
	local record = nil
	return function()
		entity, record = next(tracker, entity)
		if entity == nil then
			return
		end
		return entity, record
	end
end

local function spy_on_world_delete(world)
	local world_delete = world.delete
	world.delete = function(world, entity)
		world_delete(world, entity)
		for _, tracker in world.trackers do
			tracker.records[entity] = nil
			for _, connection in tracker.connections do
				connection()
			end
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

local function observers_add(world: jecs.World & { [string]: any }): PatchedWorld
	type Signal = { [jecs.Entity]: { (...any) -> () } }
	local signals = {
		added = {} :: Signal,
		emplaced = {} :: Signal,
		removed = {} :: Signal
	}

	world.added = function(_, component, fn)
		local listeners = signals.added[component]
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
		local max = #listeners + 1
		listeners[max] = fn
		return function()
			local n = #listeners
			listeners[max] = listeners[n]
			listeners[n] = nil
		end
	end

	world.changed = function(_, component, fn)
		local listeners = signals.emplaced[component]
		local component_index = world.component_index :: jecs.ComponentIndex
		assert(component_index[component] == nil, "You cannot use hooks on components you intend to use this signal with")
		if not listeners then
			listeners = {}
			signals.emplaced[component] = listeners
			local function on_change(entity: number, id: number, value: any)
				for _, listener in listeners :: any do
					listener(entity, id, value)
				end
			end
			world:set(component, jecs.OnChange, on_change)
		end
		local max = #listeners + 1
		listeners[max] = fn
		return function()
			local n = #listeners
			listeners[max] = listeners[n]
			listeners[n] = nil
		end
	end

	world.removed = function(_, component, fn)
		local listeners = signals.removed[component]
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
		local max = #listeners + 1
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

	world.trackers = {}

	return world :: PatchedWorld
end

return observers_add
