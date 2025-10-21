--!strict
local jecs = require("@jecs")

type World = jecs.World
type Query<T...> = jecs.Query<T...>

type Id<T=any> = jecs.Id<T>


export type Iter<T...> = (Observer<T...>) -> () -> (jecs.Entity, T...)

export type Observer<T...> = {
	disconnect: (Observer<T...>) -> (),
}

export type Monitor = {
	disconnect: () -> (),
	added: ((jecs.Entity) -> ()) -> (),
	removed: ((jecs.Entity) -> ()) -> ()
}

local function observers_new<T...>(
	query: Query<T...>,
	callback: (jecs.Entity) -> ()
): Observer<T...>
	local cachedquery = query:cached()

	local world = (cachedquery :: Query<any> & { world: World }).world
	callback = callback

	local archetypes = cachedquery.archetypes_map
	local terms = query.filter_with :: { jecs.Id<any, any> }

	local entity_index = world.entity_index

	local function emplaced<a>(
		entity: jecs.Entity,
		id: jecs.Id<a>
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

			local onadded = world:added(rel, function(entity, id)
				if not wc and id ~= term then
					return
				end
				local r = jecs.record(world, entity)
				if archetypes[r.archetype.id] then
					callback(entity)
				end
			end)
			table.insert(cleanup, onadded)
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
				local onremoved = world:removed(rel, function(entity, id)
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

local function monitors_new(query: Query<...any>): Monitor
	local cachedquery = query:cached()

	local world = (cachedquery :: Query<...any> & { world: World }).world :: jecs.World

	local archetypes = cachedquery.archetypes_map
	local terms = cachedquery.filter_with :: { jecs.Id<any, any> }

	local entity_index = world.entity_index :: any

	local callback_added: ((jecs.Entity) -> ())?
	local callback_removed: ((jecs.Entity) -> ())?

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

		if archetypes[r.archetype.id] then
			callback_added(entity)
		end
	end

	local function removed(entity: jecs.Entity, component: jecs.Component, delete:boolean?)
		if delete then
			return
		end
		if callback_removed == nil then
			return
		end
		local r = jecs.record(world, entity)
		local src = r.archetype

		local dst = jecs.archetype_traverse_remove(world, component, src)

		if not archetypes[dst.id] then
			callback_removed(entity)
		end
	end

	local cleanup = {}

	for _, term in terms do
		if jecs.IS_PAIR(term) then
			local rel = jecs.ECS_PAIR_FIRST(term)
			local tgt = jecs.ECS_PAIR_SECOND(term)
			local wc = tgt == jecs.w

			local onadded = world:added(rel, function(entity, id, _, oldarchetype)
				if callback_added == nil then
					return
				end

				if not wc and id ~= term then
					return
				end

				local r = jecs.entity_index_try_get_fast(
					entity_index, entity :: any) :: jecs.Record

				if archetypes[oldarchetype.id] and archetypes[r.archetype.id] then
					print("???")
				end
				if not archetypes[oldarchetype.id] and archetypes[r.archetype.id] then
					callback_added(entity)
				end
			end)
			local onremoved = world:removed(rel, function(entity, id)
				if callback_removed == nil then
					return
				end
				if not wc and id ~= term then
					return
				end

				local r = jecs.record(world, entity)
				if archetypes[r.archetype.id] then
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
				local onadded = world:added(rel, function(entity, id, _, oldarchetype)
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

					local dst = jecs.archetype_traverse_remove(world, id, archetype)

					if archetypes[dst.id] then
						callback_added(entity)
					end
				end)
				table.insert(cleanup, onadded)
				table.insert(cleanup, onremoved)
			else
				local onadded = world:added(term, function(entity, id, _, oldarchetype)
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
	observer = observers_new
}
