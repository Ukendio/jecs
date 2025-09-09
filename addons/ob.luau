--!strict
local jecs = require("@jecs")

type World = jecs.World
type Query<T...> = jecs.Query<T...>
type QueryInner<T...> = Query<T...> & jecs.QueryInner

type Id<T = any> = jecs.Id<T>

type Entity<T = any> = jecs.Entity<T>

export type Iter<T...> = (Observer<T...>) -> () -> (jecs.Entity, T...)

export type Observer<T...> = typeof(setmetatable(
	{} :: {
		iter: Iter<T...>,
		entities: { Entity<nil> },
		disconnect: (Observer<T...>) -> (),
	},
	{} :: {
		__iter: Iter<T...>,
	}
))

local function get_matching_archetypes(world: jecs.World, query: QueryInner<...any>)
	local archetypes = {}

	for _, archetype in query.compatible_archetypes do
		archetypes[archetype.id] = true
	end

	local terms = query.ids
	local first = terms[1]

	local observers_on_create = world.observable[jecs.ArchetypeCreate][first]
	local observer_on_create = observers_on_create[#observers_on_create]
	observer_on_create.callback = function(archetype)
		archetypes[archetype.id] = true
	end

	local observers_on_delete = world.observable[jecs.ArchetypeDelete][first]
	local observer_on_delete = observers_on_delete[#observers_on_delete]

	observer_on_delete.callback = function(archetype)
		archetypes[archetype.id] = nil
	end

	local function disconnect()
		table.remove(observers_on_create, table.find(observers_on_create, observer_on_create))
		table.remove(observers_on_delete, table.find(observers_on_delete, observer_on_delete))
	end

	return archetypes, disconnect
end

local function observers_new<T...>(query: Query<T...>, callback: ((Entity<nil>, Id<any>, value: any?) -> ())?): Observer<T...>
	query:cached()

	local world = (query :: QueryInner<T...>).world
	callback = callback

	local archetypes, disconnect_query = get_matching_archetypes(world, query :: QueryInner<T...>)

	local terms = query.ids
	local query_with = query.filter_with or terms

	local entity_index = world.entity_index :: any

	local iter_indexes = {} :: { [Entity]: number }
	local iter_queue = {} :: { Entity }

	local function remove_queued(entity: jecs.Entity, index: number)
		if index ~= nil then
			local last = table.remove(iter_queue)
			if last and last ~= entity then
				iter_queue[index] = last
				iter_indexes[last] = index
			end
			iter_indexes[entity] = nil
		end
	end

	local function emplaced<T>(entity: jecs.Entity, id: jecs.Id<T>, value: T?)
		local r = entity_index.sparse_array[jecs.ECS_ID(entity)]
		local index = iter_indexes[entity]
		if r == nil then
			remove_queued(entity, index)
		end
		local archetype = r.archetype

		if archetypes[archetype.id] then
			if index == nil then
				table.insert(iter_queue, entity)
				iter_indexes[entity] = #iter_queue
			end
			if callback ~= nil then
				callback(entity :: Entity, id, value)
			end
		end
	end

	local function removed(entity: jecs.Entity)
		local index = iter_indexes[entity]
		if index ~= nil then
			remove_queued(entity, index)
		end
	end

	local hooked = {} :: { () -> () }
	for _, term in query_with do
		if jecs.IS_PAIR(term) then
			term = jecs.ECS_PAIR_FIRST(term)
		end
		table.insert(hooked, world:added(term, emplaced))
		table.insert(hooked, world:changed(term, emplaced))
		table.insert(hooked, world:removed(term, removed))
	end

	local function disconnect()
		disconnect_query()
		for _, unhook in hooked do
			unhook()
		end
	end

	local function iter()
		local row = #iter_queue
		return function()
			if row == 0 then
				table.clear(iter_queue)
				table.clear(iter_indexes)
			end
			local entity = iter_queue[row]
			row -= 1
			return entity
		end
	end

	local observer = {
		disconnect = disconnect,
		entities = iter_queue,
		__iter = iter,
		iter = iter,
	}

	setmetatable(observer, observer)

	return (observer :: any) :: Observer<T...>
end

local function monitors_new<T...>(query: Query<T...>, callback: ((Entity<nil>, Id<any>, value: any?) -> ())?): Observer<T...>
	query:cached()

	local world = (query :: QueryInner<T...>).world

	local archetypes, disconnect_query = get_matching_archetypes(world, query :: QueryInner<T...>)

	local terms = query.ids
	local query_with = query.filter_with or terms

	local entity_index = world.entity_index :: any
	local i = 0
	local entities = {}

	local function emplaced<T, a>(entity: jecs.Entity<T>, id: jecs.Id<a>, value: a?)
		local r = jecs.entity_index_try_get_fast(entity_index, entity :: any) :: jecs.Record
		if not r or not r.archetype then
			if callback then
				callback(entity :: Entity, jecs.OnRemove)
			end
			return
		end

		local archetype = r.archetype

		if archetypes[archetype.id] then
			i += 1
			entities[i] = entity
			if callback ~= nil then
				callback(entity :: Entity, jecs.OnAdd)
			end
		else
			if callback ~= nil then
				callback(entity :: Entity, jecs.OnRemove)
			end
		end
	end

	local function removed(entity: jecs.Entity, component: jecs.Id)
		local r = jecs.record(world, entity)
		if not r or not archetypes[r.archetype.id] then
			return
		end
		local EcsOnRemove = jecs.OnRemove :: jecs.Id
		if callback ~= nil then
			callback(entity, EcsOnRemove)
		end
	end

	local hooked = {} :: { () -> () }
	for _, term in query_with do
		if jecs.IS_PAIR(term) then
			term = jecs.ECS_PAIR_FIRST(term)
		end
		table.insert(hooked, world:added(term, emplaced))
		table.insert(hooked, world:removed(term, removed))
	end

	local function disconnect()
		disconnect_query()
		for _, unhook in hooked do
			unhook()
		end
	end

	local function iter()
		local row = i
		return function()
			if row == 0 then
				i = 0
				table.clear(entities)
			end
			local entity = entities[row]
			row -= 1
			return entity
		end
	end

	local observer = {
		disconnect = disconnect,
		entities = entities,
		__iter = iter,
		iter = iter,
	}

	setmetatable(observer, observer)

	return (observer :: any) :: Observer<T...>
end

return {
	monitor = monitors_new,
	observer = observers_new,
}
