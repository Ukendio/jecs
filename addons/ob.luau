--!strict
local jecs = require("@jecs")

type World = jecs.World

type Id<T=any> = jecs.Id<T>


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
	local cachedquery = query:cached()

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
	local cachedquery = query:cached()

	local world = (cachedquery :: jecs.Query<...any> & { world: World }).world :: jecs.World

	local archetypes = cachedquery.archetypes_map
	local terms = cachedquery.filter_with :: { jecs.Id<any> }

	local entity_index = world.entity_index :: any

	local terms_lookup: { [jecs.Id<any>]: boolean } = {}
	for _, term in terms do
		terms_lookup[term] = true
	end

	local callback_added: ((jecs.Entity) -> ())?
	local callback_removed: ((jecs.Entity) -> ())?

	-- NOTE(marcus): Track the last (entity, old archetype) pair we processed to detect bulk operations.
	-- During bulk_insert from ROOT_ARCHETYPE, the entity is moved to the target archetype first,
	-- then all on_add callbacks fire sequentially with the same oldarchetype for the same entity.
	-- We track both entity and old archetype to distinguish between:
	-- 1. Same entity, same old archetype (bulk operation - skip)
	-- 2. Different entity, same old archetype (separate operation - don't skip)
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
			-- NOTE(marcus): Skip if we've seen this exact (entity, old archetype) combination before
			-- AND this component is in the query's terms. This detects bulk operations where
			-- the same entity transitions with multiple components, while allowing different
			-- entities to trigger even if they share the same old archetype.
			if last_old_archetype == oldarchetype and last_entity == entity and terms_lookup[id] then
				return
			end

			last_old_archetype = oldarchetype
			last_entity = entity
			callback_added(entity)
		else
			-- NOTE(marcus): Clear tracking when we see a different transition pattern
			last_old_archetype = nil
			last_entity = nil
		end
	end

	-- Track which entity we've already processed for deletion to avoid duplicate callbacks
	-- during bulk deletion where multiple components are removed with delete=true
	local last_deleted_entity: jecs.Entity? = nil

	local function removed(entity: jecs.Entity, component: jecs.Component, delete:boolean?)
		if callback_removed == nil then
			return
		end

		if delete then
			-- Deletion is a bulk removal - all components are removed with delete=true
			-- We should only trigger the callback once per entity, not once per component
			if last_deleted_entity == entity then
				return
			end

			local r = jecs.record(world, entity)
			if r and r.archetype and archetypes[r.archetype.id] then
				-- Entity was in the monitor before deletion
				last_deleted_entity = entity
				-- Clear tracking when entity is deleted
				last_old_archetype = nil
				last_entity = nil
				callback_removed(entity)
			end
			return
		end

		local r = jecs.record(world, entity)
		local src = r.archetype

		local dst = jecs.archetype_traverse_remove(world, component, src)

		if not archetypes[dst.id] then
			-- Clear tracking when entity leaves the monitor to allow re-entry
			last_old_archetype = nil
			last_entity = nil
			last_deleted_entity = nil
			callback_removed(entity)
		end
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
					-- NOTE(marcus): Skip if we've seen this exact (entity, old archetype) combination before
					-- AND this component is in the query's terms.
					if last_old_archetype == oldarchetype and last_entity == entity and terms_lookup[id] then
						return
					end

					last_old_archetype = oldarchetype
					last_entity = entity
					callback_added(entity)
				else
					-- Clear tracking when we see a different transition pattern
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
				if archetypes[r.archetype.id] then
					last_old_archetype = nil
					callback_removed(entity)
				end
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

					-- NOTE(marcus): This check that it was presently in
					-- the query but distinctively leaves is important as
					-- sometimes it could be too eager to report that it
					-- removed a component even though the entity is not
					-- apart of the monitor
					if archetypes[oldarchetype.id] and not archetypes[archetype.id] then
						last_old_archetype = nil
						callback_removed(entity)
					end
				end)
				local onremoved = world:removed(rel, function(entity, id, delete)
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
					if last_old_archetype == archetype and terms_lookup[id] then
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

					-- NOTE(marcus): Sometimes OnAdd listeners for excluded
					-- terms are too eager to report that it is leaving the
					-- monitor even though the entity is not apart of it
					-- already.
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

					-- NOTE(marcus): Inversely with the opposite operation, you
					-- only need to check if it is going to enter the query once
					-- because world:remove already stipulates that it is
					-- idempotent so that this hook won't be invoked if it is
					-- was already removed.
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
