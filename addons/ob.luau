--!strict
local jecs = require("@jecs")

type World = jecs.World
type Query<T...> = jecs.Query<T...>

type Id<T=any> = jecs.Id<T>

type Entity<T> = jecs.Entity<T>

export type Iter<T...> = (Observer<T...>) -> () -> (jecs.Entity, T...)

export type Observer<T...> = {
	disconnect: (Observer<T...>) -> (),
	added: ((jecs.Entity) -> ()) -> (),
	removed: ((jecs.Entity) -> ()) -> ()
}

local function observers_new<T...>(
	query: Query<T...>,
	callback: ((Entity<nil>) -> ())
): Observer<T...>
	query:cached()


	local world = (query :: Query<T...> & { world: World }).world
	callback = callback

	local archetypes = {}
	local terms = query.filter_with :: { jecs.Id }
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

	local entity_index = world.entity_index :: any

	for _, archetype in query:archetypes() do
		archetypes[archetype.id] = true
	end

	local function emplaced<T, a>(
		entity: jecs.Entity<T>,
		id: jecs.Id<a>,
		value: a?
	)
		local r = entity_index.sparse_array[jecs.ECS_ID(entity)]

		local archetype = r.archetype

		if archetypes[archetype.id] then
			callback(entity)
		end
	end

	local cleanup = {}

	for _, term in terms do
		if jecs.IS_PAIR(term) then
			term = jecs.ECS_PAIR_FIRST(term)
		end
		local onadded = world:added(term, emplaced)
		local onchanged = world:changed(term, emplaced)
		table.insert(cleanup, onadded)
		table.insert(cleanup, onchanged)
 	end

	local without = query.filter_without
   	if without then
		for _, term in without do
			if jecs.IS_PAIR(term) then
				local rel = jecs.ECS_PAIR_SECOND(term)
				local tgt = jecs.ECS_PAIR_SECOND(term)
				local wc = tgt == jecs.w
				local onremoved = world:removed(rel, function(entity, id)
					if not wc and term ~= tgt then
						return
					end
					local r = jecs.record(world, entity)
					local archetype = r.archetype
					if archetype then
						local dst = jecs.archetype_traverse_remove(world, id, archetype)
						if archetypes[dst.id] then
							callback(entity)
						end
					end
				end)

				table.insert(cleanup, onremoved)
			else
				local onremoved = world:removed(term, function(entity, id)
					local r = jecs.record(world, entity)
					local archetype = r.archetype
					if archetype then
						local dst = jecs.archetype_traverse_remove(world, id, archetype)
						if archetypes[dst.id] then
							callback(entity)
						end
					end
				end)

				table.insert(cleanup, onremoved)
			end
		end
	end

 	local function disconnect()
  		table.remove(observers_on_create, table.find(
	  		observers_on_create,
	    	observer_on_create
	   	))

	   	table.remove(observers_on_delete, table.find(
	      	observers_on_delete,
	       	observer_on_delete
       	))

		table.clear(archetypes)

		for _, disconnect in cleanup do
			disconnect()
		end
   	end

	local observer = {
  		disconnect = disconnect,
   	}

    return (observer :: any) :: Observer<T...>
end

local function monitors_new<T...>(query: Query<T...>): Observer<T...>
	query:cached()

	local world = (query :: Query<T...> & { world: World }).world

	local archetypes = {}
	local terms = query.filter_with :: { jecs.Id<any> }
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

	for _, archetype in query:archetypes() do
		archetypes[archetype.id] = true
	end
	local entity_index = world.entity_index :: any

	local callback_added: ((jecs.Entity) -> ())?
	local callback_removed: ((jecs.Entity) -> ())?

	local function emplaced<T, a>(
		entity: jecs.Entity<T>,
		id: jecs.Id<a>,
		value: a?
	)
		if callback_added == nil then
			return
		end

		local r = jecs.entity_index_try_get_fast(
			entity_index, entity :: any) :: jecs.Record

		local archetype = r.archetype

		if archetypes[archetype.id] then
			callback_added(entity)
		end
	end

	local function removed(entity: jecs.Entity, component: jecs.Id)
		if callback_removed == nil then
			return
		end
		local r = jecs.record(world, entity)
		if not archetypes[r.archetype.id] then
			return
		end
		callback_removed(entity)
	end

	local cleanup = {}

	for _, term in terms do
		if jecs.IS_PAIR(term) then
			term = jecs.ECS_PAIR_FIRST(term)
		end
		local onadded = world:added(term, emplaced)
		local onremoved = world:removed(term, removed)
		table.insert(cleanup, onadded)
		table.insert(cleanup, onremoved)
 	end

  	local without = query.filter_without
   	if without then
	   	for _, term in without do
			if jecs.IS_PAIR(term) then
				local rel = jecs.ECS_PAIR_FIRST(term)
				local tgt = jecs.ECS_PAIR_SECOND(term)
				local wc = tgt == jecs.w
				local onadded = world:added(rel, function(entity, id)
					if callback_removed == nil then
						return
					end
					if not wc and id ~= term then
						return
					end
					local r = jecs.record(world, entity)
					local archetype = r.archetype
					if archetype then
						local dst = jecs.archetype_traverse_remove(world, id, archetype)
						if archetypes[dst.id] then
							callback_removed(entity)
						end
					end
				end)
				local onremoved = world:removed(rel, function(entity, id)
					if callback_added == nil then
						return
					end
					if not wc and id ~= term then
						return
					end
					local r = jecs.record(world, entity)
					local archetype = r.archetype
					if archetype then
						local dst = jecs.archetype_traverse_remove(world, id, archetype)
						if archetypes[dst.id] then
							callback_added(entity)
						end
					end
				end)
				table.insert(cleanup, onadded)
				table.insert(cleanup, onremoved)
			else
				local onadded = world:added(term, function(entity, id)
					if callback_removed == nil then
						return
					end
					local r = jecs.record(world, entity)
					local archetype = r.archetype
					if archetype then
						local dst = jecs.archetype_traverse_remove(world, id, archetype)
						if archetypes[dst.id] then
							callback_removed(entity)
						end
					end
				end)
				local onremoved = world:removed(term, function(entity, id)
					if callback_added == nil then
						return
					end
					local r = jecs.record(world, entity)
					local archetype = r.archetype
					if archetype then
						local dst = jecs.archetype_traverse_remove(world, id, archetype)
						if archetypes[dst.id] then
							callback_added(entity)
						end
					end
				end)
				table.insert(cleanup, onadded)
				table.insert(cleanup, onremoved)
			end
    	end
    end

 	local function disconnect()
  		table.remove(observers_on_create, table.find(
	  		observers_on_create,
	    	observer_on_create
	   	))

	   	table.remove(observers_on_delete, table.find(
	      	observers_on_delete,
	       	observer_on_delete
       	))

		table.clear(archetypes)

		for _, disconnect in cleanup do
			disconnect()
		end
   	end

    local function monitor_added(callback)
		callback_added = callback
    end

    local function monitor_removed(callback)
    	callback_removed = callback
    end

	local observer = {
  		disconnect = disconnect,
    	added = monitor_added,
     	removed = monitor_removed
   	}

    return (observer :: any) :: Observer<T...>
end

return {
	monitor = monitors_new,
	observer = observers_new
}
