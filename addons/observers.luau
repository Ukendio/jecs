local jecs = require("@jecs")
local testkit = require("@testkit")

local function observers_new(world, description)
	local query = description.query
	local callback = description.callback
	local terms = query.filter_with
	if not terms then
		local ids = query.ids
		query.filter_with = ids
		terms = ids
	end

	local entity_index = world.entity_index
	local function emplaced(entity)
		local r = jecs.entity_index_try_get_fast(
			entity_index, entity)

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

local function world_track(world, ...)
	local entity_index = world.entity_index
	local terms = { ... }
	local q_shim = { filter_with = terms }

	local n = 0
	local dense_array = {}
	local sparse_array = {}

	local function emplaced(entity)
		local r = jecs.entity_index_try_get_fast(
			entity_index, entity)

		local archetype = r.archetype

		if jecs.query_match(q_shim, archetype) then
			n += 1
			dense_array[n] = entity
			sparse_array[entity] = n
		end
	end

	local function removed(entity)
		local i = sparse_array[entity]
		if i ~= n then
			dense_array[i] = dense_array[n]
		end

		dense_array[n] = nil
	end

	for _, term in terms do
		world:added(term, emplaced)
		world:changed(term, emplaced)
 	end

	local function iter()
		local i = n
		return function()
			local row = i
			if row == 0 then
				return nil
			end
			i -= 1
			return dense_array[row]
		end
	end

	local it = {
		__iter = iter,
		without = function(self, ...)
			q_shim.filter_without = { ... }
			return self
		end
	}
	return setmetatable(it, it)
end

local function observers_add(world)
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
					listener(entity)
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
					listener(entity, value)
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
					listener(entity)
				end
			end
		end
		table.insert(listeners, fn)
	end

	world.signals = signals

	world.track = world_track

	world.observer = observers_new
	return world
end

return observers_add
