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
	local signals = {
		added = {},
		emplaced = {},
		removed = {}
	}

	world.added = function(_, component, fn)
		local listeners = signals.added[component]
		if not listeners then
			listeners = {}
			signals.added[component] = listeners
			local idr = jecs.id_record_ensure(world, component)
			idr.hooks.on_add = function(entity)
				for _, listener in listeners do
					listener(entity, component)
				end
			end
		end
		table.insert(listeners, fn)
	end

	world.changed = function(_, component, fn)
		local listeners = signals.emplaced[component]
		if not listeners then
			listeners = {}
			signals.emplaced[component] = listeners
			local idr = jecs.id_record_ensure(world, component)
			idr.hooks.on_change = function(entity, value)
				for _, listener in listeners do
					listener(entity, component, value)
				end
			end
		end
		table.insert(listeners, fn)
	end

	world.removed = function(_, component, fn)
		local listeners = signals.removed[component]
		if not listeners then
			listeners = {}
			signals.removed[component] = listeners
			local idr = jecs.id_record_ensure(world, component)
			idr.hooks.on_remove = function(entity)
				for _, listener in listeners do
					listener(entity, component)
				end
			end
		end
		table.insert(listeners, fn)
	end

	world.signals = signals

	world.observer = observers_new

	world.monitor = monitors_new

	return world
end

local world = jecs.world()

observers_add(world):observer({
	callback = function() end,
	query = world:query(1 :: any)
})

observers_add(world):added(1 :: any, function()

end)

return {
	add = observers_add
}
