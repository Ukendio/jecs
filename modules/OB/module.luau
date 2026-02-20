--!strict
local jecs = require("@jecs")

type World = jecs.World

type Id<T=any> = jecs.Id<any>

local function duplicate(query: jecs.Query<...any>): jecs.Cached_Query<...any>
	local world = (query :: { world: World }).world
	local dup = world:query()
	dup.filter_with = table.clone(query.filter_with)
	if query.filter_without then
		dup.filter_without = query.filter_without
	end
	return dup:cached()
end

export type Observer = {
	disconnect: () -> (),
}

export type Monitor = {
	disconnect: () -> (),
	added: ((jecs.Entity) -> ()) -> (),
	removed: ((jecs.Entity) -> ()) -> ()
}

local function observers_new(
	query: jecs.Query<...any>,
	callback: (jecs.Entity) -> ()
): Observer
	local cachedquery = duplicate(query)

	local world = (cachedquery :: jecs.Query<any> & { world: World }).world
	callback = callback

	local archetypes = cachedquery.archetypes_map
	local terms = query.filter_with :: { jecs.Id<any> }

	local entity_index = world.entity_index

	local function emplaced<a>(
		entity: jecs.Entity,
		id: jecs.Id<a>,
		value: a,
		oldarchetype: jecs.Archetype
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
			local rel = jecs.ECS_PAIR_FIRST(term)
			local tgt = jecs.ECS_PAIR_SECOND(term)
			local wc = tgt == jecs.w

			local function emplaced_w_pair(entity, id, value, oldarchetype: jecs.Archetype)
				if not wc and id ~= term then
					return
				end
				local r = jecs.record(world, entity)
				if archetypes[r.archetype.id] then
					callback(entity)
				end
			end

			local onadded = world:added(rel, emplaced_w_pair)
			local onchanged = world:changed(rel, emplaced_w_pair)
			table.insert(cleanup, onadded)
			table.insert(cleanup, onchanged)
		else
			local onadded = world:added(term, emplaced)
			local onchanged = world:changed(term, emplaced)
			table.insert(cleanup, onadded)
			table.insert(cleanup, onchanged)
		end
 	end

	local without = query.filter_without
	if without then
		for _, term in without do
			if jecs.IS_PAIR(term) then
				local rel = jecs.ECS_PAIR_FIRST(term)
				local tgt = jecs.ECS_PAIR_SECOND(term)
				local wc = tgt == jecs.w
				local onremoved = world:removed(rel, function(entity, id, delete: boolean?)
					if delete then
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
							callback(entity)
						end
					end
				end)

				table.insert(cleanup, onremoved)
			else
				local onremoved = world:removed(term, function(entity, id, delete: boolean?)
					if delete then
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
			end
		end
	end

 	local function disconnect()
		for _, disconnect in cleanup do
			disconnect()
		end
   	end

	local observer = {
  		disconnect = disconnect,
   	}

    return observer
end

local function monitors_new(query: jecs.Query<...any>): Monitor
	local cachedquery = duplicate(query)

	local world = (cachedquery :: jecs.Query<...any> & { world: World }).world :: jecs.World

	local archetypes = cachedquery.archetypes_map
	local terms = cachedquery.filter_with :: { jecs.Id<any> }

	local entity_index = world.entity_index :: any

	local callback_added: ((jecs.Entity) -> ())?
	local callback_removed: ((jecs.Entity) -> ())?

	local last_old_archetype: jecs.Archetype? = nil
	local last_entity: jecs.Entity? = nil

	local function emplaced<a>(
 		entity: jecs.Entity,
 		id: jecs.Id<a>,
 		value: a,
 		oldarchetype: jecs.Archetype
 	)
 		if callback_added == nil then
 			return
 		end

		local r = jecs.entity_index_try_get_fast(
			entity_index, entity :: any) :: jecs.Record
		if not archetypes[oldarchetype.id] and archetypes[r.archetype.id] then
			if last_old_archetype == oldarchetype and last_entity == entity then
				return
			end

			last_old_archetype = oldarchetype
			last_entity = entity
			callback_added(entity)
		else
			last_old_archetype = nil
			last_entity = nil
		end
	end

	local function removed(entity: jecs.Entity, component: jecs.Component, delete:boolean?)
		if callback_removed == nil then
			return
		end

		local r = jecs.record(world, entity)
		if not r then return end

		local src = r.archetype
		if not src then return end

		if not archetypes[src.id] then return end

		if last_entity == entity and last_old_archetype == src then
			return
		end

		last_entity = entity
		last_old_archetype = src
		callback_removed(entity)
	end

	local cleanup = {}

	for _, term in terms do
		if jecs.IS_PAIR(term) then
			local rel = jecs.ECS_PAIR_FIRST(term)
			local tgt = jecs.ECS_PAIR_SECOND(term)
			local wc = tgt == jecs.w

			local onadded = world:added(rel, function(entity, id, _, oldarchetype: jecs.Archetype)
				if callback_added == nil then
					return
				end

				if not wc and id ~= term then
					return
				end

				local r = jecs.entity_index_try_get_fast(
					entity_index, entity :: any) :: jecs.Record

				if not archetypes[oldarchetype.id] and archetypes[r.archetype.id] then
					if last_old_archetype == oldarchetype and last_entity == entity then
						return
					end

					last_old_archetype = oldarchetype
					last_entity = entity
					callback_added(entity)
				else
					last_old_archetype = nil
					last_entity = nil
				end
			end)
			local onremoved = world:removed(rel, function(entity, id, deleted)
				if callback_removed == nil then
					return
				end
				if not wc and id ~= term then
					return
				end

				local r = jecs.record(world, entity)
				local src = r.archetype

				if last_entity == entity and last_old_archetype == src then
					return
				end
				if not archetypes[src.id] then
					return
				end
				last_entity = entity
				last_old_archetype = src
				callback_removed(entity)
			end)
			table.insert(cleanup, onadded)
			table.insert(cleanup, onremoved)
		else
			local onadded = world:added(term, emplaced)
			local onremoved = world:removed(term, removed)
			table.insert(cleanup, onadded)
			table.insert(cleanup, onremoved)
		end

 	end

  	local without = query.filter_without
   	if without then
	   	for _, term in without do
			if jecs.IS_PAIR(term) then
				local rel = jecs.ECS_PAIR_FIRST(term)
				local tgt = jecs.ECS_PAIR_SECOND(term)
				local wc = tgt == jecs.w
				local onadded = world:added(rel, function(entity, id, _, oldarchetype: jecs.Archetype)
					if callback_removed == nil then
						return
					end
					if not wc and id ~= term then
						return
					end
					local r = jecs.record(world, entity)
					local archetype = r.archetype
					if not archetype then
						return
					end

					if archetypes[oldarchetype.id] and not archetypes[archetype.id] then
						last_old_archetype = nil
						callback_removed(entity)
					end
				end)
				local onremoved = world:removed(rel, function(entity: jecs.Entity, id: jecs.Id, delete)
					if delete then
						return
					end
					if callback_added == nil then
						return
					end
					if not wc and id ~= term then
						return
					end

					local r = jecs.record(world, entity)
					local archetype = r.archetype
					if not archetype then
						return
					end
					if last_old_archetype == archetype then
						return
					end

					local dst = jecs.archetype_traverse_remove(world, id, archetype)

					if archetypes[dst.id] then
						last_old_archetype = archetype
						callback_added(entity)
					end
				end)
				table.insert(cleanup, onadded)
				table.insert(cleanup, onremoved)
			else
				local onadded = world:added(term, function(entity, id, _, oldarchetype: jecs.Archetype)
					if callback_removed == nil then
						return
					end
					local r = jecs.record(world, entity)
					local archetype = r.archetype
					if not archetype then
						return
					end

					if archetypes[oldarchetype.id] and not archetypes[archetype.id] then
						callback_removed(entity)
					end
				end)
				local onremoved = world:removed(term, function(entity, id, delete)
					if delete then
						return
					end
					if callback_added == nil then
						return
					end
					local r = jecs.record(world, entity)
					local archetype = r.archetype
					if not archetype then
						return
					end
					local dst = jecs.archetype_traverse_remove(world, id, archetype)

					if archetypes[dst.id] then
						callback_added(entity)
					end
				end)
				table.insert(cleanup, onadded)
				table.insert(cleanup, onremoved)
			end
    	end
    end

 	local function disconnect()
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

	local monitor = {
  		disconnect = disconnect,
    	added = monitor_added,
     	removed = monitor_removed
   	} :: Monitor

    return monitor
end

return {
	monitor = monitors_new,
	observer = observers_new,
	test = function(q: jecs.Query<...any>) end
}
