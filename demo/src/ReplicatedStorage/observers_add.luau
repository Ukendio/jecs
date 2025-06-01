local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.ecs)

type Observer<T...> = {
	callback: (jecs.Entity) -> (),
	query: jecs.Query<T...>,
}

export type PatchedWorld = jecs.World & {
	added: <T>(PatchedWorld, jecs.Id<T>, (e: jecs.Entity, id: jecs.Id<T>, value: T) -> ()) -> (),
	removed: (PatchedWorld, jecs.Id, (e: jecs.Entity, id: jecs.Id) -> ()) -> (),
	changed: <T>(PatchedWorld, jecs.Id<T>, (e: jecs.Entity, id: jecs.Id<T>, value: T) -> ()) -> (),
	-- deleted: (PatchedWorld, () -> ()) -> () -> (),
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

local function observers_add(world: jecs.World): PatchedWorld
	local signals = {
		added = {},
		emplaced = {},
		removed = {},
		deleted = {}
	}

	world = world :: jecs.World & {[string]: any}

	world.added = function(_, component, fn)
		local listeners = signals.added[component]
		if not listeners then
			listeners = {}
			signals.added[component] = listeners

			local idr = jecs.id_record_ensure(world :: any, component :: any)
			local rw = jecs.pair(component, jecs.Wildcard)
			local idr_r = jecs.id_record_ensure(world :: any, rw :: any)
			local function on_add(entity: number, id: number, value: any)
				for _, listener in listeners do
					listener(entity, id, value)
				end
			end
			world:set(component, jecs.OnAdd, on_add)
			idr.hooks.on_add = on_add :: any
			idr_r.hooks.on_add = on_add :: any
		end
		table.insert(listeners, fn)
	end

	world.changed = function(_, component, fn)
		local listeners = signals.emplaced[component]
		if not listeners then
			listeners = {}
			signals.emplaced[component] = listeners
			local idr = jecs.id_record_ensure(world :: any, component :: any)
			local rw = jecs.pair(component, jecs.Wildcard)
			local idr_r = jecs.id_record_ensure(world :: any, rw :: any)
			local function on_change(entity: number, id: number, value: any)
				for _, listener in listeners do
					listener(entity, id, value)
				end
			end
			world:set(component, jecs.OnChange, on_change)
			idr.hooks.on_change = on_change :: any
			idr_r.hooks.on_change = on_change :: any
		end
		table.insert(listeners, fn)
	end

	world.removed = function(_, component, fn)
		local listeners = signals.removed[component]
		if not listeners then
			listeners = {}
			signals.removed[component] = listeners
			local idr = jecs.id_record_ensure(world :: any, component :: any)
			local rw = jecs.pair(component, jecs.Wildcard)
			local idr_r = jecs.id_record_ensure(world :: any, rw :: any)
			local function on_remove(entity: number, id: number, value: any)
				for _, listener in listeners do
					listener(entity, id, value)
				end
			end
			world:set(component, jecs.OnRemove, on_remove)
			idr.hooks.on_remove = on_remove :: any
			idr_r.hooks.on_remove = on_remove :: any
		end
		table.insert(listeners, fn)
	end

	world.signals = signals

	world.observer = observers_new

	world.monitor = monitors_new

	-- local world_delete = world.delete

	-- world.deleted = function(_, fn)
	-- 	local listeners = signals.deleted
	-- 	table.insert(listeners, fn)
	-- end
	-- world.delete = function(world, entity)
	-- 	world_delete(world, entity)
	-- 	for _, fn in signals.deleted do
	-- 		fn(entity)
	-- 	end
	-- end

	return world :: PatchedWorld
end

return observers_add
