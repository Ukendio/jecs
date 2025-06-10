local bit = require("bit")
local ECS_ENTITY_MASK = bit.lshift(1, 24)
local ECS_GENERATION_MASK = bit.lshift(1, 16)
local ECS_PAIR_OFFSET = 2 ^ 48

local ECS_ID_DELETE = 2 --0b01
local ECS_ID_IS_TAG = 1 --0b10
local ECS_ID_MASK = 0   --0b00

local function table_create(n, v)
	if v == nil then
		return {}
	end
	local t = {}
	for i = 1, n do
		t[i] = v
	end
	return t
end

local function table_find(tbl, val)
	for i, v in tbl do
		if v == val then
			return i
		end
	end
	return nil
end

local function table_clone(tbl)
	local t = {}
	for i, v in ipairs(tbl) do
		t[i] = v
	end
	return t
end

local HI_COMPONENT_ID = 256
local EcsOnAdd = HI_COMPONENT_ID + 1
local EcsOnRemove = HI_COMPONENT_ID + 2
local EcsOnChange = HI_COMPONENT_ID + 3
local EcsWildcard = HI_COMPONENT_ID + 4
local EcsChildOf = HI_COMPONENT_ID + 5
local EcsComponent = HI_COMPONENT_ID + 6
local EcsOnDelete = HI_COMPONENT_ID + 7
local EcsOnDeleteTarget = HI_COMPONENT_ID + 8
local EcsDelete = HI_COMPONENT_ID + 9
local EcsRemove = HI_COMPONENT_ID + 10
local EcsName = HI_COMPONENT_ID + 11
local EcsOnArchetypeCreate = HI_COMPONENT_ID + 12
local EcsOnArchetypeDelete = HI_COMPONENT_ID + 13
local EcsRest = HI_COMPONENT_ID + 14

local NULL_ARRAY = {}
local NULL = newproxy(false)

local ECS_INTERNAL_ERROR = [[
	This is an internal error, please file a bug report via the following link:

	https://github.com/Ukendio/jecs/issues/new?template=BUG-REPORT.md
]]

local function ecs_assert(condition, msg)
	if not condition then
		error(msg)
	end
end

local ecs_metadata = {}
local ecs_max_component_id = 0
local ecs_max_tag_id = EcsRest

local function ECS_COMPONENT()
	ecs_max_component_id = ecs_max_component_id + 1
	if ecs_max_component_id > HI_COMPONENT_ID then
		error("Too many components")
	end
	return ecs_max_component_id
end

local function ECS_TAG()
	ecs_max_tag_id = ecs_max_tag_id + 1
	return ecs_max_tag_id
end

local function ECS_META(id, ty, value)
	local bundle = ecs_metadata[id]
	if bundle == nil then
		bundle = {}
		ecs_metadata[id] = bundle
	end
	if value == nil then
		bundle[ty] = NULL
	else
		bundle[ty] = value
	end
end

local function ECS_META_RESET()
	ecs_metadata = {}
	ecs_max_component_id = 0
	ecs_max_tag_id = EcsRest
end

local function ECS_COMBINE(id, generation)
	return id + (generation * ECS_ENTITY_MASK)
end

local function ECS_IS_PAIR(e)
	return e > ECS_PAIR_OFFSET
end

local function ECS_GENERATION_INC(e)
	if e > ECS_ENTITY_MASK then
		local id = bit.rshift(e, ECS_ENTITY_MASK)
		local generation = bit.band(e, ECS_ENTITY_MASK)

		local next_gen = generation + 1
		if next_gen >= ECS_GENERATION_MASK then
			return id
		end

		return ECS_COMBINE(id, next_gen)
	end
	return ECS_COMBINE(e, 1)
end

local function ECS_ENTITY_T_LO(e)
	if e > ECS_ENTITY_MASK then
		return bit.band(e, ECS_ENTITY_MASK)
	end
	return e
end

local function ECS_ID(e)
	if e > ECS_ENTITY_MASK then
		return bit.band(e, ECS_ENTITY_MASK)
	end
	return e
end

local function ECS_GENERATION(e)
	if e > ECS_ENTITY_MASK then
		return bit.rshift(e, ECS_ENTITY_MASK)
	end
	return e
end

local function ECS_ENTITY_T_HI(e)
	if e > ECS_ENTITY_MASK then
		return bit.rshift(e, ECS_ENTITY_MASK)
	end
	return e
end

local function ECS_PAIR(pred, obj)
	pred = bit.band(pred, ECS_ENTITY_MASK)
	obj = bit.band(obj, ECS_ENTITY_MASK)

	return obj + (pred * ECS_ENTITY_MASK) + ECS_PAIR_OFFSET
end

local function ECS_PAIR_FIRST(e)
	return bit.rshift((e - ECS_PAIR_OFFSET), ECS_ENTITY_MASK)
end

local function ECS_PAIR_SECOND(e)
	return bit.band((e - ECS_PAIR_OFFSET), ECS_ENTITY_MASK)
end

local function entity_index_try_get_any(
	entity_index,
	entity
)
	local r = entity_index.sparse_array[ECS_ENTITY_T_LO(entity)]

	if not r or r.dense == 0 then
		return nil
	end

	return r
end

local function entity_index_try_get(entity_index, entity)
	local r = entity_index_try_get_any(entity_index, entity)
	if r then
		local r_dense = r.dense
		if r_dense > entity_index.alive_count then
			return nil
		end
		if entity_index.dense_array[r_dense] ~= entity then
			return nil
		end
	end
	return r
end

local function entity_index_try_get_fast(entity_index, entity)
	local id = ECS_ENTITY_T_LO(entity)
	local r = entity_index.sparse_array[id]
	if r then
		if entity_index.dense_array[r.dense] ~= entity then
			return nil
		end
	end
	return r
end

local function entity_index_is_alive(entity_index, entity)
	return entity_index_try_get(entity_index, entity) ~= nil
end

local function entity_index_get_alive(entity_index, entity)
	local r = entity_index_try_get_any(entity_index, entity)
	if r then
		return entity_index.dense_array[r.dense]
	end
	return nil
end

local function ecs_get_alive(world, entity)
	if entity == 0 then
		return 0
	end

	local eindex = world.entity_index

	if entity_index_is_alive(eindex, entity) then
		return entity
	end

	if entity > ECS_ENTITY_MASK then
		return 0
	end

	local current = entity_index_get_alive(eindex, entity)
	if not current or not entity_index_is_alive(eindex, current) then
		return 0
	end

	return current
end

local ECS_INTERNAL_ERROR_INCOMPATIBLE_ENTITY = "Entity is outside range"

local function entity_index_new_id(entity_index)
	local dense_array = entity_index.dense_array
	local alive_count = entity_index.alive_count
	local sparse_array = entity_index.sparse_array
	local max_id = entity_index.max_id

	if alive_count < max_id then
		alive_count = alive_count + 1
		entity_index.alive_count = alive_count
		local id = dense_array[alive_count]
		return id
	end

	local id = max_id + 1
	local range_end = entity_index.range_end
	ecs_assert(range_end == nil or id < range_end, ECS_INTERNAL_ERROR_INCOMPATIBLE_ENTITY)

	entity_index.max_id = id
	alive_count = alive_count + 1
	entity_index.alive_count = alive_count
	dense_array[alive_count] = id
	sparse_array[id] = { dense = alive_count }

	return id
end

local function ecs_pair_first(world, e)
	local pred = ECS_PAIR_FIRST(e)
	return ecs_get_alive(world, pred)
end

local function ecs_pair_second(world, e)
	local obj = ECS_PAIR_SECOND(e)
	return ecs_get_alive(world, obj)
end

local function query_match(query,
						   archetype)
	local records = archetype.records
	local with = query.filter_with

	for _, id in with do
		if not records[id] then
			return false
		end
	end

	local without = query.filter_without
	if without then
		for _, id in without do
			if records[id] then
				return false
			end
		end
	end

	return true
end

local function find_observers(world, event, component)
	local cache = world.observable[event]
	if not cache then
		return nil
	end
	return cache[component]
end

local function archetype_move(
	entity_index,
	to,
	dst_row,
	from,
	src_row
)
	local src_columns = from.columns
	local dst_columns = to.columns
	local dst_entities = to.entities
	local src_entities = from.entities

	local last = #src_entities
	local id_types = from.types
	local records = to.records

	for i, column in ipairs(src_columns) do
		if column ~= NULL_ARRAY then
			-- Retrieves the new column index from the source archetype's record from each component
			-- We have to do this because the columns are tightly packed and indexes may not correspond to each other.
			local tr = records[id_types[i]]
			-- Sometimes target column may not exist, e.g. when you remove a component.
			if tr then
				dst_columns[tr][dst_row] = column[src_row]
			end
			-- If the entity is the last row in the archetype then swapping it would be meaningless.
			if src_row ~= last then
				-- Swap rempves columns to ensure there are no holes in the archetype.
				column[src_row] = column[last]
			end
			column[last] = nil
		end
	end

	local moved = #src_entities

	-- Move the entity from the source to the destination archetype.
	-- Because we have swapped columns we now have to update the records
	-- corresponding to the entities' rows that were swapped.
	local e1 = src_entities[src_row]
	local e2 = src_entities[moved]

	if src_row ~= moved then
		src_entities[src_row] = e2
	end

	src_entities[moved] = nil
	dst_entities[dst_row] = e1

	local sparse_array = entity_index.sparse_array

	local record1 = sparse_array[ECS_ENTITY_T_LO(e1)]
	local record2 = sparse_array[ECS_ENTITY_T_LO(e2)]
	record1.row = dst_row
	record2.row = src_row
end

local function archetype_append(
	entity,
	archetype
)
	local entities = archetype.entities
	local length = #entities + 1
	entities[length] = entity
	return length
end

local function new_entity(
	entity,
	record,
	archetype
)
	local row = archetype_append(entity, archetype)
	record.archetype = archetype
	record.row = row
	return record
end

local function entity_move(
	entity_index,
	entity,
	record,
	to
)
	local sourceRow = record.row
	local from = record.archetype
	local dst_row = archetype_append(entity, to)
	archetype_move(entity_index, to, dst_row, from, sourceRow)
	record.archetype = to
	record.row = dst_row
end

local function hash(arr)
	return table.concat(arr, "_")
end

local function fetch(id, records, columns, row)
	local tr = records[id]

	if not tr then
		return nil
	end

	return columns[tr][row]
end

local function world_get(world, entity, a, b, c, d, e)
	local record = entity_index_try_get_fast(world.entity_index, entity)
	if not record then
		return nil
	end

	local archetype = record.archetype
	if not archetype then
		return nil
	end

	local records = archetype.records
	local columns = archetype.columns
	local row = record.row

	local va = fetch(a, records, columns, row)

	if not b then
		return va
	elseif not c then
		return va, fetch(b, records, columns, row)
	elseif not d then
		return va, fetch(b, records, columns, row), fetch(c, records, columns, row)
	elseif not e then
		return va, fetch(b, records, columns, row), fetch(c, records, columns, row), fetch(d, records, columns, row)
	else
		error("args exceeded")
	end
end

local function world_has_one_inline(world, entity, id)
	local record = entity_index_try_get_fast(world.entity_index, entity)
	if not record then
		return false
	end

	local archetype = record.archetype
	if not archetype then
		return false
	end

	local records = archetype.records

	return records[id] ~= nil
end

local function ecs_is_tag(world, entity)
	local idr = world.component_index[entity]
	if idr then
		return bit.band(idr.flags, ECS_ID_IS_TAG) ~= 0
	end
	return not world_has_one_inline(world, entity, EcsComponent)
end

local function world_has(world, entity, a, b, c, d, e)
	local record = entity_index_try_get_fast(world.entity_index, entity)
	if not record then
		return false
	end

	local archetype = record.archetype
	if not archetype then
		return false
	end

	local records = archetype.records

	return records[a] ~= nil and
		(b == nil or records[b] ~= nil) and
		(c == nil or records[c] ~= nil) and
		(d == nil or records[d] ~= nil) and
		(e == nil or error("args exceeded"))
end

local function world_target(world, entity, relation, index)
	local nth = index or 0
	local record = entity_index_try_get_fast(world.entity_index, entity)
	if not record then
		return nil
	end

	local archetype = record.archetype
	if not archetype then
		return nil
	end

	local r = ECS_PAIR(relation, EcsWildcard)

	local count = archetype.counts[r]
	if not count then
		return nil
	end

	if nth >= count then
		nth = nth + count + 1
	end

	nth = archetype.types[nth + archetype.records[r]]
	if not nth then
		return nil
	end

	return entity_index_get_alive(world.entity_index,
		ECS_PAIR_SECOND(nth))
end

local function ECS_ID_IS_WILDCARD(e)
	local first = ECS_ENTITY_T_HI(e)
	local second = ECS_ENTITY_T_LO(e)
	return first == EcsWildcard or second == EcsWildcard
end

local function id_record_ensure(world, id)
	local component_index = world.component_index
	local entity_index = world.entity_index
	local idr = component_index[id]

	if idr then
		return idr
	end

	local flags = ECS_ID_MASK
	local relation = id
	local target = 0
	local is_pair = ECS_IS_PAIR(id)
	if is_pair then
		relation = entity_index_get_alive(entity_index, ECS_PAIR_FIRST(id))
		ecs_assert(relation and entity_index_is_alive(
			entity_index, relation), ECS_INTERNAL_ERROR)
		target = entity_index_get_alive(entity_index, ECS_PAIR_SECOND(id))
		ecs_assert(target and entity_index_is_alive(
			entity_index, target), ECS_INTERNAL_ERROR)
	end

	local cleanup_policy = world_target(world, relation, EcsOnDelete, 0)
	local cleanup_policy_target = world_target(world, relation, EcsOnDeleteTarget, 0)

	local has_delete = false

	if cleanup_policy == EcsDelete or cleanup_policy_target == EcsDelete then
		has_delete = true
	end

	local on_add, on_change, on_remove = world_get(world,
		relation, EcsOnAdd, EcsOnChange, EcsOnRemove)

	local is_tag = not world_has_one_inline(world,
		relation, EcsComponent)

	if is_tag and is_pair then
		is_tag = not world_has_one_inline(world, target, EcsComponent)
	end

	if has_delete then
		flags = bit.bor(flags, ECS_ID_DELETE)
	end

	if is_tag then
		flags = bit.bor(flags, ECS_ID_IS_TAG)
	end

	idr = {
		size = 0,
		cache = {},
		counts = {},
		flags = flags,
		hooks = {
			on_add = on_add,
			on_change = on_change,
			on_remove = on_remove,
		},
	}

	component_index[id] = idr

	return idr
end

local function archetype_append_to_records(
	idr,
	archetype,
	id,
	index
)
	local archetype_id = archetype.id
	local archetype_records = archetype.records
	local archetype_counts = archetype.counts
	local idr_columns = idr.cache
	local idr_counts = idr.counts
	local tr = idr_columns[archetype_id]
	if not tr then
		idr_columns[archetype_id] = index
		idr_counts[archetype_id] = 1

		archetype_records[id] = index
		archetype_counts[id] = 1
	else
		local max_count = idr_counts[archetype_id] + 1
		idr_counts[archetype_id] = max_count
		archetype_counts[id] = max_count
	end
end

local function archetype_create(world, id_types, ty)
	local archetype_id = world.max_archetype_id + 1
	world.max_archetype_id = archetype_id

	local columns = {}
	local records = {}
	local counts = {}

	local archetype = {
		columns = columns,
		entities = {},
		id = archetype_id,
		records = records,
		counts = counts,
		type = ty,
		types = id_types,
	}

	for i, component_id in ipairs(id_types) do
		local idr = id_record_ensure(world, component_id)
		archetype_append_to_records(idr, archetype, component_id, i)

		if ECS_IS_PAIR(component_id) then
			local relation = ECS_PAIR_FIRST(component_id)
			local object = ECS_PAIR_SECOND(component_id)
			local r = ECS_PAIR(relation, EcsWildcard)
			local idr_r = id_record_ensure(world, r)
			archetype_append_to_records(idr_r, archetype, r, i)

			local t = ECS_PAIR(EcsWildcard, object)
			local idr_t = id_record_ensure(world, t)
			archetype_append_to_records(idr_t, archetype, t, i)
		end

		if bit.band(idr.flags, ECS_ID_IS_TAG) == 0 then
			columns[i] = {}
		else
			columns[i] = NULL_ARRAY
		end
	end

	for id in pairs(records) do
		local observer_list = find_observers(world, EcsOnArchetypeCreate, id)
		if observer_list then
			for _, observer in ipairs(observer_list) do
				if query_match(observer.query, archetype) then
					observer.callback(archetype)
				end
			end
		end
	end

	world.archetype_index[ty] = archetype
	world.archetypes[archetype_id] = archetype
	world.archetype_edges[archetype.id] = {}

	return archetype
end

local function world_range(world, range_begin, range_end)
	local entity_index = world.entity_index

	entity_index.range_begin = range_begin
	entity_index.range_end = range_end

	local max_id = entity_index.max_id

	if range_begin > max_id then
		local dense_array = entity_index.dense_array
		local sparse_array = entity_index.sparse_array

		for i = max_id + 1, range_begin do
			dense_array[i] = i
			sparse_array[i] = {
				dense = 0
			}
		end
		entity_index.max_id = range_begin - 1
		entity_index.alive_count = range_begin - 1
	end
end

local function world_entity(world, entity)
	local entity_index = world.entity_index
	if entity then
		local index = ECS_ID(entity)
		local max_id = entity_index.max_id
		local sparse_array = entity_index.sparse_array
		local dense_array = entity_index.dense_array
		local alive_count = entity_index.alive_count
		local r = sparse_array[index]
		if r then
			local dense = r.dense

			if not dense or r.dense == 0 then
				r.dense = index
				dense = index
			end

			local any = dense_array[dense]
			if dense <= alive_count then
				if any ~= entity then
					error("Entity ID is already in use with a different generation")
				else
					return entity
				end
			end

			local e_swap = dense_array[dense]
			local r_swap = entity_index_try_get_any(entity_index, e_swap)
			alive_count = alive_count + 1
			entity_index.alive_count = alive_count
			r_swap.dense = dense
			r.dense = alive_count
			dense_array[dense] = e_swap
			dense_array[alive_count] = entity

			return entity
		else
			for i = max_id + 1, index do
				sparse_array[i] = { dense = i }
				dense_array[i] = i
			end
			entity_index.max_id = index

			local e_swap = dense_array[alive_count]
			local r_swap = sparse_array[alive_count]
			r_swap.dense = index

			alive_count = alive_count + 1
			entity_index.alive_count = alive_count

			r = sparse_array[index]

			r.dense = alive_count

			sparse_array[index] = r

			dense_array[index] = e_swap
			dense_array[alive_count] = entity


			return entity
		end
	end
	return entity_index_new_id(entity_index)
end

local function world_parent(world, entity)
	return world_target(world, entity, EcsChildOf, 0)
end

local function archetype_ensure(world, id_types)
	if #id_types < 1 then
		return world.ROOT_ARCHETYPE
	end

	local ty = hash(id_types)
	local archetype = world.archetype_index[ty]
	if archetype then
		return archetype
	end

	return archetype_create(world, id_types, ty)
end

local function find_insert(id_types, toAdd)
	for i, id in ipairs(id_types) do
		if id == toAdd then
			error("Duplicate component id")
			return -1
		end
		if id > toAdd then
			return i
		end
	end
	return #id_types + 1
end

local function find_archetype_without(world, node, id)
	local id_types = node.types
	local at = table_find(id_types, id)

	local dst = table_clone(id_types)
	table.remove(dst, at)

	return archetype_ensure(world, dst)
end


local function archetype_traverse_remove(world, id, from)
	local edges = world.archetype_edges
	local edge = edges[from.id]

	local to = edge[id]
	if to == nil then
		to = find_archetype_without(world, from, id)
		edge[id] = to
		edges[to.id][id] = from
	end

	return to
end

local function find_archetype_with(world, id, from)
	local id_types = from.types

	local at = find_insert(id_types, id)
	local dst = table_clone(id_types)
	table.insert(dst, at, id)

	return archetype_ensure(world, dst)
end

local function archetype_traverse_add(world, id, from)
	from = from or world.ROOT_ARCHETYPE
	if from.records[id] then
		return from
	end
	local edges = world.archetype_edges
	local edge = edges[from.id]

	local to = edge[id]
	if not to then
		to = find_archetype_with(world, id, from)
		edge[id] = to
		edges[to.id][id] = from
	end

	return to
end

local function world_add(world, entity, id)
	local entity_index = world.entity_index
	local record = entity_index_try_get_fast(entity_index, entity)
	if not record then
		return
	end

	local from = record.archetype
	local to = archetype_traverse_add(world, id, from)
	if from == to then
		return
	end
	if from then
		entity_move(entity_index, entity, record, to)
	else
		if #to.types > 0 then
			new_entity(entity, record, to)
		end
	end

	local idr = world.component_index[id]
	local on_add = idr.hooks.on_add

	if on_add then
		on_add(entity, id)
	end
end

local function world_set(world, entity, id, data)
	local entity_index = world.entity_index
	local record = entity_index_try_get_fast(entity_index, entity)
	if not record then
		return
	end

	local from = record.archetype
	local to = archetype_traverse_add(world, id, from)
	local idr = world.component_index[id]
	local idr_hooks = idr.hooks

	if from == to then
		local tr = to.records[id]
		local column = from.columns[tr]
		column[record.row] = data

		-- If the archetypes are the same it can avoid moving the entity
		-- and just set the data directly.
		local on_change = idr_hooks.on_change
		if on_change then
			on_change(entity, id, data)
		end

		return
	end

	if from then
		-- If there was a previous archetype, then the entity needs to move the archetype
		entity_move(entity_index, entity, record, to)
	else
		if #to.types > 0 then
			-- When there is no previous archetype it should create the archetype
			new_entity(entity, record, to)
		end
	end

	local tr = to.records[id]
	local column = to.columns[tr]

	column[record.row] = data

	local on_add = idr_hooks.on_add
	if on_add then
		on_add(entity, id, data)
	end
end

local function world_component(world)
	local id = world.max_component_id + 1
	if id > HI_COMPONENT_ID then
		-- IDs are partitioned into ranges because component IDs are not nominal,
		-- so it needs to error when IDs intersect into the entity range.
		error("Too many components, consider using world:entity() instead to create components.")
	end
	world.max_component_id = id

	return id
end

local function world_remove(world, entity, id)
	local entity_index = world.entity_index
	local record = entity_index_try_get_fast(entity_index, entity)
	if not record then
		return
	end
	local from = record.archetype

	if not from then
		return
	end

	if from.records[id] then
		local idr = world.component_index[id]
		local on_remove = idr.hooks.on_remove
		if on_remove then
			on_remove(entity, id)
		end

		local to = archetype_traverse_remove(world, id, record.archetype)

		entity_move(entity_index, entity, record, to)
	end
end

local function archetype_fast_delete_last(columns, column_count)
	for _, column in ipairs(columns) do
		if column ~= NULL_ARRAY then
			column[column_count] = nil
		end
	end
end

local function archetype_fast_delete(columns, column_count, row)
	for _, column in ipairs(columns) do
		if column ~= NULL_ARRAY then
			column[row] = column[column_count]
			column[column_count] = nil
		end
	end
end

local function archetype_delete(world, archetype, row)
	local entity_index = world.entity_index
	local component_index = world.component_index
	local columns = archetype.columns
	local id_types = archetype.types
	local entities = archetype.entities
	local column_count = #entities
	local last = #entities
	local move = entities[last]
	-- We assume first that the entity is the last in the archetype
	local delete = move

	if row ~= last then
		local record_to_move = entity_index_try_get_any(entity_index, move)
		if record_to_move then
			record_to_move.row = row
		end

		delete = entities[row]
		entities[row] = move
	end

	for _, id in ipairs(id_types) do
		local idr = component_index[id]
		local on_remove = idr.hooks.on_remove
		if on_remove then
			on_remove(delete, id)
		end
	end

	entities[last] = nil

	if row == last then
		archetype_fast_delete_last(columns, column_count)
	else
		archetype_fast_delete(columns, column_count, row)
	end
end

local function world_clear(world, entity)
	local entity_index = world.entity_index
	local component_index = world.component_index
	local archetypes = world.archetypes
	local tgt = ECS_PAIR(EcsWildcard, entity)
	local idr_t = component_index[tgt]
	local idr = component_index[entity]
	local rel = ECS_PAIR(entity, EcsWildcard)
	local idr_r = component_index[rel]

	if idr then
		local count = 0
		local queue = {}
		for archetype_id in idr.cache do
			local idr_archetype = archetypes[archetype_id]
			local entities = idr_archetype.entities
			local n = #entities
			count = count + n
			table.move(entities, 1, n, #queue + 1, queue)
		end
		for _, e in queue do
			world_remove(world, e, entity)
		end
	end

	if idr_t then
		local queue
		local ids

		local count = 0
		local archetype_ids = idr_t.cache
		for archetype_id in pairs(archetype_ids) do
			local idr_t_archetype = archetypes[archetype_id]
			local idr_t_types = idr_t_archetype.types
			local entities = idr_t_archetype.entities
			local removal_queued = false

			for _, id in idr_t_types do
				if ECS_IS_PAIR(id) then
					local object = entity_index_get_alive(
						entity_index, ECS_PAIR_SECOND(id))
					if object ~= entity then
						if not ids then
							ids = {}
						end
						ids[id] = true
						removal_queued = true
					end
				end
			end

			if removal_queued then
				if not queue then
					queue = {}
				end

				local n = #entities
				table.move(entities, 1, n, count + 1, queue)
				count = count + n
			end
		end

		for id in ids do
			for _, child in queue do
				world_remove(world, child, id)
			end
		end
	end

	if idr_r then
		local count = 0
		local archetype_ids = idr_r.cache
		local ids = {}
		local queue = {}
		for archetype_id in archetype_ids do
			local idr_r_archetype = archetypes[archetype_id]
			local entities = idr_r_archetype.entities
			local tr = idr_r_archetype.records[rel]
			local tr_count = idr_r_archetype.counts[rel]
			local types = idr_r_archetype.types
			for i = tr, tr + tr_count - 1 do
				ids[types[i]] = true
			end
			local n = #entities
			table.move(entities, 1, n, count + 1, queue)
			count = count + n
		end

		for _, e in queue do
			for id in ids do
				world_remove(world, e, id)
			end
		end
	end
end

local function archetype_destroy(world, archetype)
	if archetype == world.ROOT_ARCHETYPE then
		return
	end

	local component_index = world.component_index
	local archetype_edges = world.archetype_edges

	for id, edge in pairs(archetype_edges[archetype.id]) do
		archetype_edges[edge.id][id] = nil
	end

	local archetype_id = archetype.id
	world.archetypes[archetype_id] = nil
	world.archetype_index[archetype.type] = nil
	local records = archetype.records

	for id in pairs(records) do
		local observer_list = find_observers(world, EcsOnArchetypeDelete, id)
		if observer_list then
			for _, observer in observer_list do
				if query_match(observer.query, archetype) then
					observer.callback(archetype)
				end
			end
		end
	end

	for id in pairs(records) do
		local idr = component_index[id]
		idr.cache[archetype_id] = nil
		idr.counts[archetype_id] = nil
		idr.size = idr.size - 1
		records[id] = nil
		if idr.size == 0 then
			component_index[id] = nil
		end
	end
end

local function world_cleanup(world)
	local archetypes = world.archetypes

	for _, archetype in archetypes do
		if #archetype.entities == 0 then
			archetype_destroy(world, archetype)
		end
	end

	local new_archetypes = table_create(#archetypes)
	local new_archetype_map = {}

	for index, archetype in archetypes do
		new_archetypes[index] = archetype
		new_archetype_map[archetype.type] = archetype
	end

	world.archetypes = new_archetypes
	world.archetype_index = new_archetype_map
end

local function world_delete(world, entity)
	local entity_index = world.entity_index
	local record = entity_index_try_get(entity_index, entity)
	if not record then
		return
	end

	local archetype = record.archetype
	local row = record.row

	if archetype then
		-- In the future should have a destruct mode for
		-- deleting archetypes themselves. Maybe requires recycling
		archetype_delete(world, archetype, row)
	end

	local delete = entity
	local component_index = world.component_index
	local archetypes = world.archetypes
	local tgt = ECS_PAIR(EcsWildcard, delete)
	local rel = ECS_PAIR(delete, EcsWildcard)

	local idr_t = component_index[tgt]
	local idr = component_index[delete]
	local idr_r = component_index[rel]

	if idr then
		local flags = idr.flags
		if bit.band(flags, ECS_ID_DELETE) ~= 0 then
			for archetype_id in pairs(idr.cache) do
				local idr_archetype = archetypes[archetype_id]

				local entities = idr_archetype.entities
				local n = #entities
				for i = n, 1, -1 do
					world_delete(world, entities[i])
				end

				archetype_destroy(world, idr_archetype)
			end
		else
			for archetype_id in idr.cache do
				local idr_archetype = archetypes[archetype_id]
				local entities = idr_archetype.entities
				local n = #entities
				for i = n, 1, -1 do
					world_remove(world, entities[i], delete)
				end

				archetype_destroy(world, idr_archetype)
			end
		end
	end

	if idr_t then
		local children
		local ids

		local count = 0
		local archetype_ids = idr_t.cache
		for archetype_id in pairs(archetype_ids) do
			local idr_t_archetype = archetypes[archetype_id]
			local idr_t_types = idr_t_archetype.types
			local entities = idr_t_archetype.entities
			local removal_queued = false

			for _, id in ipairs(idr_t_types) do
				if ECS_IS_PAIR(id) then
					local object = entity_index_get_alive(
						entity_index, ECS_PAIR_SECOND(id))
					if object == delete then
						local id_record = component_index[id]
						local flags = id_record.flags
						local flags_delete_mask = bit.band(flags, ECS_ID_DELETE)
						if flags_delete_mask ~= 0 then
							for i = #entities, 1, -1 do
								local child = entities[i]
								world_delete(world, child)
							end
							break
						else
							if not ids then
								ids = {}
							end
							ids[id] = true
							removal_queued = true
						end
					end
				end
			end

			if removal_queued then
				if not children then
					children = {}
				end
				local n = #entities
				table.move(entities, 1, n, count + 1, children)
				count = count + n
			end
		end

		if ids then
			for _, child in ipairs(children) do
				for id in ids do
					world_remove(world, child, id)
				end
			end
		end

		for archetype_id in pairs(archetype_ids) do
			archetype_destroy(world, archetypes[archetype_id])
		end
	end

	if idr_r then
		local archetype_ids = idr_r.cache
		local flags = idr_r.flags
		if (bit.band(flags, ECS_ID_DELETE)) ~= 0 then
			for archetype_id in pairs(archetype_ids) do
				local idr_r_archetype = archetypes[archetype_id]
				local entities = idr_r_archetype.entities
				local n = #entities
				for i = n, 1, -1 do
					world_delete(world, entities[i])
				end
				archetype_destroy(world, idr_r_archetype)
			end
		else
			local children = {}
			local count = 0
			local ids = {}
			for archetype_id in pairs(archetype_ids) do
				local idr_r_archetype = archetypes[archetype_id]
				local entities = idr_r_archetype.entities
				local tr = idr_r_archetype.records[rel]
				local tr_count = idr_r_archetype.counts[rel]
				local types = idr_r_archetype.types
				for i = tr, tr + tr_count - 1 do
					ids[types[i]] = true
				end
				local n = #entities
				table.move(entities, 1, n, count + 1, children)
				count = count + n
			end

			for _, child in ipairs(children) do
				for id in ids do
					world_remove(world, child, id)
				end
			end

			for archetype_id in pairs(archetype_ids) do
				archetype_destroy(world, archetypes[archetype_id])
			end
		end
	end

	local dense_array = entity_index.dense_array
	local dense = record.dense
	local i_swap = entity_index.alive_count
	entity_index.alive_count = i_swap - 1

	local e_swap = dense_array[i_swap]
	local r_swap = entity_index_try_get_any(entity_index, e_swap)

	r_swap.dense = dense
	record.archetype = nil
	record.row = nil
	record.dense = i_swap

	dense_array[dense] = e_swap
	dense_array[i_swap] = ECS_GENERATION_INC(entity)
end

local function world_exists(world, entity)
	return entity_index_try_get_any(world.entity_index, entity) ~= nil
end

local function world_contains(world, entity)
	return entity_index_is_alive(world.entity_index, entity)
end

local function NOOP() end

local function query_iter_init(query)
	local world_query_iter_next

	local compatible_archetypes = query.compatible_archetypes
	local lastArchetype = 1
	local archetype = compatible_archetypes[1]
	if not archetype then
		return NOOP
	end
	local columns = archetype.columns
	local entities = archetype.entities
	local i = #entities
	local records = archetype.records

	local ids = query.ids
	local A, B, C, D, E, F, G, H, I = unpack(ids)
	local a, b, c, d, e, f, g, h

	if not B then
		a = columns[records[A]]
	elseif not C then
		a = columns[records[A]]
		b = columns[records[B]]
	elseif not D then
		a = columns[records[A]]
		b = columns[records[B]]
		c = columns[records[C]]
	elseif not E then
		a = columns[records[A]]
		b = columns[records[B]]
		c = columns[records[C]]
		d = columns[records[D]]
	elseif not F then
		a = columns[records[A]]
		b = columns[records[B]]
		c = columns[records[C]]
		d = columns[records[D]]
		e = columns[records[E]]
	elseif not G then
		a = columns[records[A]]
		b = columns[records[B]]
		c = columns[records[C]]
		d = columns[records[D]]
		e = columns[records[E]]
		f = columns[records[F]]
	elseif not H then
		a = columns[records[A]]
		b = columns[records[B]]
		c = columns[records[C]]
		d = columns[records[D]]
		e = columns[records[E]]
		f = columns[records[F]]
		g = columns[records[G]]
	elseif not I then
		a = columns[records[A]]
		b = columns[records[B]]
		c = columns[records[C]]
		d = columns[records[D]]
		e = columns[records[E]]
		f = columns[records[F]]
		g = columns[records[G]]
		h = columns[records[H]]
	end

	if not B then
		function world_query_iter_next()
			local entity = entities[i]
			while entity == nil do
				lastArchetype = lastArchetype + 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i ~= 0 then
					entity = entities[i]
					columns = archetype.columns
					records = archetype.records
					a = columns[records[A]]
				end
			end

			local row = i
			i = i - 1

			return entity, a[row]
		end
	elseif not C then
		function world_query_iter_next()
			local entity = entities[i]
			while entity == nil do
				lastArchetype = lastArchetype + 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i ~= 0 then
					entity = entities[i]
					columns = archetype.columns
					records = archetype.records
					a = columns[records[A]]
					b = columns[records[B]]
				end
			end

			local row = i
			i = i - 1

			return entity, a[row], b[row]
		end
	elseif not D then
		function world_query_iter_next()
			local entity = entities[i]
			while entity == nil do
				lastArchetype = lastArchetype + 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i ~= 0 then
					entity = entities[i]
					columns = archetype.columns
					records = archetype.records
					a = columns[records[A]]
					b = columns[records[B]]
					c = columns[records[C]]
				end
			end

			local row = i
			i = i - 1

			return entity, a[row], b[row], c[row]
		end
	elseif not E then
		function world_query_iter_next()
			local entity = entities[i]
			while entity == nil do
				lastArchetype = lastArchetype + 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i ~= 0 then
					entity = entities[i]
					columns = archetype.columns
					records = archetype.records
					a = columns[records[A]]
					b = columns[records[B]]
					c = columns[records[C]]
					d = columns[records[D]]
				end
			end

			local row = i
			i = i - 1

			return entity, a[row], b[row], c[row], d[row]
		end
	elseif not F then
		function world_query_iter_next()
			local entity = entities[i]
			while entity == nil do
				lastArchetype = lastArchetype + 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i ~= 0 then
					entity = entities[i]
					columns = archetype.columns
					records = archetype.records
					a = columns[records[A]]
					b = columns[records[B]]
					c = columns[records[C]]
					d = columns[records[D]]
					e = columns[records[E]]
				end
			end

			local row = i
			i = i - 1

			return entity, a[row], b[row], c[row], d[row], e[row]
		end
	elseif not G then
		function world_query_iter_next()
			local entity = entities[i]
			while entity == nil do
				lastArchetype = lastArchetype + 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i ~= 0 then
					entity = entities[i]
					columns = archetype.columns
					records = archetype.records
					a = columns[records[A]]
					b = columns[records[B]]
					c = columns[records[C]]
					d = columns[records[D]]
					e = columns[records[E]]
					f = columns[records[F]]
				end
			end

			local row = i
			i = i - 1

			return entity, a[row], b[row], c[row], d[row], e[row], f[row]
		end
	elseif not H then
		function world_query_iter_next()
			local entity = entities[i]
			while entity == nil do
				lastArchetype = lastArchetype + 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i ~= 0 then
					entity = entities[i]
					columns = archetype.columns
					records = archetype.records
					a = columns[records[A]]
					b = columns[records[B]]
					c = columns[records[C]]
					d = columns[records[D]]
					e = columns[records[E]]
					f = columns[records[F]]
					g = columns[records[G]]
				end
			end

			local row = i
			i = i - 1

			return entity, a[row], b[row], c[row], d[row], e[row], f[row], g[row]
		end
	elseif not I then
		function world_query_iter_next()
			local entity = entities[i]
			while entity == nil do
				lastArchetype = lastArchetype + 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i ~= 0 then
					entity = entities[i]
					columns = archetype.columns
					records = archetype.records
					a = columns[records[A]]
					b = columns[records[B]]
					c = columns[records[C]]
					d = columns[records[D]]
					e = columns[records[E]]
					f = columns[records[F]]
					g = columns[records[G]]
					h = columns[records[H]]
				end
			end

			local row = i
			i = i - 1

			return entity, a[row], b[row], c[row], d[row], e[row], f[row], g[row], h[row]
		end
	else
		local output = {}
		function world_query_iter_next()
			local entity = entities[i]
			while entity == nil do
				lastArchetype = lastArchetype + 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i ~= 0 then
					entity = entities[i]
					columns = archetype.columns
					records = archetype.records
				end
			end

			local row = i
			i = i - 1

			for j, id in ids do
				output[j] = columns[records[id]][row]
			end

			return entity, unpack(output)
		end
	end

	query.next = world_query_iter_next
	return world_query_iter_next
end

local function query_iter(query)
	local query_next = query.next
	if not query_next then
		query_next = query_iter_init(query)
	end
	return query_next
end

local function query_without(query, ...)
	local without = { ... }
	query.filter_without = without
	local compatible_archetypes = query.compatible_archetypes
	for i = #compatible_archetypes, 1, -1 do
		local archetype = compatible_archetypes[i]
		local records = archetype.records
		local matches = true

		for _, id in without do
			if records[id] then
				matches = false
				break
			end
		end

		if not matches then
			local last = #compatible_archetypes
			if last ~= i then
				compatible_archetypes[i] = compatible_archetypes[last]
			end
			compatible_archetypes[last] = nil
		end
	end

	return query
end

local function query_with(query, ...)
	local compatible_archetypes = query.compatible_archetypes
	local with = { ... }
	query.filter_with = with

	for i = #compatible_archetypes, 1, -1 do
		local archetype = compatible_archetypes[i]
		local records = archetype.records
		local matches = true

		for _, id in with do
			if not records[id] then
				matches = false
				break
			end
		end

		if not matches then
			local last = #compatible_archetypes
			if last ~= i then
				compatible_archetypes[i] = compatible_archetypes[last]
			end
			compatible_archetypes[last] = nil
		end
	end

	return query
end

-- Meant for directly iterating over archetypes to minimize
-- function call overhead. Should not be used unless iterating over
-- hundreds of thousands of entities in bulk.
local function query_archetypes(query)
	return query.compatible_archetypes
end

local function query_cached(query)
	local with = query.filter_with
	local ids = query.ids
	if with then
		table.move(ids, 1, #ids, #with + 1, with)
	else
		query.filter_with = ids
	end

	local compatible_archetypes = query.compatible_archetypes
	local lastArchetype = 1

	local A, B, C, D, E, F, G, H, I = unpack(ids)
	local a, b, c, d, e, f, g, h

	local world_query_iter_next
	local columns
	local entities
	local i
	local archetype
	local records
	local archetypes = query.compatible_archetypes

	local world = query.world
	-- Only need one observer for EcsArchetypeCreate and EcsArchetypeDelete respectively
	-- because the event will be emitted for all components of that Archetype.
	local observable = world.observable
	local on_create_action = observable[EcsOnArchetypeCreate]
	if not on_create_action then
		on_create_action = {}
		observable[EcsOnArchetypeCreate] = on_create_action
	end
	local query_cache_on_create = on_create_action[A]
	if not query_cache_on_create then
		query_cache_on_create = {}
		on_create_action[A] = query_cache_on_create
	end

	local on_delete_action = observable[EcsOnArchetypeDelete]
	if not on_delete_action then
		on_delete_action = {}
		observable[EcsOnArchetypeDelete] = on_delete_action
	end
	local query_cache_on_delete = on_delete_action[A]
	if not query_cache_on_delete then
		query_cache_on_delete = {}
		on_delete_action[A] = query_cache_on_delete
	end

	local function on_create_callback(archetype)
		table.insert(archetypes, archetype)
	end

	local function on_delete_callback(archetype)
		local i = table_find(archetypes, archetype)
		if i == nil then
			return
		end
		local n = #archetypes
		archetypes[i] = archetypes[n]
		archetypes[n] = nil
	end

	local observer_for_create = { query = query, callback = on_create_callback }
	local observer_for_delete = { query = query, callback = on_delete_callback }

	table.insert(query_cache_on_create, observer_for_create)
	table.insert(query_cache_on_delete, observer_for_delete)

	local function cached_query_iter()
		lastArchetype = 1
		archetype = compatible_archetypes[lastArchetype]
		if not archetype then
			return NOOP
		end
		entities = archetype.entities
		i = #entities
		records = archetype.records
		columns = archetype.columns
		if not B then
			a = columns[records[A]]
		elseif not C then
			a = columns[records[A]]
			b = columns[records[B]]
		elseif not D then
			a = columns[records[A]]
			b = columns[records[B]]
			c = columns[records[C]]
		elseif not E then
			a = columns[records[A]]
			b = columns[records[B]]
			c = columns[records[C]]
			d = columns[records[D]]
		elseif not F then
			a = columns[records[A]]
			b = columns[records[B]]
			c = columns[records[C]]
			d = columns[records[D]]
			e = columns[records[E]]
		elseif not G then
			a = columns[records[A]]
			b = columns[records[B]]
			c = columns[records[C]]
			d = columns[records[D]]
			e = columns[records[E]]
			f = columns[records[F]]
		elseif not H then
			a = columns[records[A]]
			b = columns[records[B]]
			c = columns[records[C]]
			d = columns[records[D]]
			e = columns[records[E]]
			f = columns[records[F]]
			g = columns[records[G]]
		elseif not I then
			a = columns[records[A]]
			b = columns[records[B]]
			c = columns[records[C]]
			d = columns[records[D]]
			e = columns[records[E]]
			f = columns[records[F]]
			g = columns[records[G]]
			h = columns[records[H]]
		end

		return world_query_iter_next
	end

	if not B then
		function world_query_iter_next()
			local entity = entities[i]
			while entity == nil do
				lastArchetype = lastArchetype + 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i ~= 0 then
					entity = entities[i]
					columns = archetype.columns
					records = archetype.records
					a = columns[records[A]]
				end
			end

			local row = i
			i = i - 1

			return entity, a[row]
		end
	elseif not C then
		function world_query_iter_next()
			local entity = entities[i]
			while entity == nil do
				lastArchetype = lastArchetype + 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i ~= 0 then
					entity = entities[i]
					columns = archetype.columns
					records = archetype.records
					a = columns[records[A]]
					b = columns[records[B]]
				end
			end

			local row = i
			i = i - 1

			return entity, a[row], b[row]
		end
	elseif not D then
		function world_query_iter_next()
			local entity = entities[i]
			while entity == nil do
				lastArchetype = lastArchetype + 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i ~= 0 then
					entity = entities[i]
					columns = archetype.columns
					records = archetype.records
					a = columns[records[A]]
					b = columns[records[B]]
					c = columns[records[C]]
				end
			end

			local row = i
			i = i - 1

			return entity, a[row], b[row], c[row]
		end
	elseif not E then
		function world_query_iter_next()
			local entity = entities[i]
			while entity == nil do
				lastArchetype = lastArchetype + 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i ~= 0 then
					entity = entities[i]
					columns = archetype.columns
					records = archetype.records
					a = columns[records[A]]
					b = columns[records[B]]
					c = columns[records[C]]
					d = columns[records[D]]
				end
			end

			local row = i
			i = i - 1

			return entity, a[row], b[row], c[row], d[row]
		end
	elseif not F then
		function world_query_iter_next()
			local entity = entities[i]
			while entity == nil do
				lastArchetype = lastArchetype + 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i ~= 0 then
					entity = entities[i]
					columns = archetype.columns
					records = archetype.records
					a = columns[records[A]]
					b = columns[records[B]]
					c = columns[records[C]]
					d = columns[records[D]]
					e = columns[records[E]]
				end
			end

			local row = i
			i = i - 1

			return entity, a[row], b[row], c[row], d[row], e[row]
		end
	elseif not G then
		function world_query_iter_next()
			local entity = entities[i]
			while entity == nil do
				lastArchetype = lastArchetype + 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i ~= 0 then
					entity = entities[i]
					columns = archetype.columns
					records = archetype.records
					a = columns[records[A]]
					b = columns[records[B]]
					c = columns[records[C]]
					d = columns[records[D]]
					e = columns[records[E]]
					f = columns[records[F]]
				end
			end

			local row = i
			i = i - 1

			return entity, a[row], b[row], c[row], d[row], e[row], f[row]
		end
	elseif not H then
		function world_query_iter_next()
			local entity = entities[i]
			while entity == nil do
				lastArchetype = lastArchetype + 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i ~= 0 then
					entity = entities[i]
					columns = archetype.columns
					records = archetype.records
					a = columns[records[A]]
					b = columns[records[B]]
					c = columns[records[C]]
					d = columns[records[D]]
					e = columns[records[E]]
					f = columns[records[F]]
					g = columns[records[G]]
				end
			end

			local row = i
			i = i - 1

			return entity, a[row], b[row], c[row], d[row], e[row], f[row], g[row]
		end
	elseif not I then
		function world_query_iter_next()
			local entity = entities[i]
			while entity == nil do
				lastArchetype = lastArchetype + 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i ~= 0 then
					entity = entities[i]
					columns = archetype.columns
					records = archetype.records
					a = columns[records[A]]
					b = columns[records[B]]
					c = columns[records[C]]
					d = columns[records[D]]
					e = columns[records[E]]
					f = columns[records[F]]
					g = columns[records[G]]
					h = columns[records[H]]
				end
			end

			local row = i
			i = i - 1

			return entity, a[row], b[row], c[row], d[row], e[row], f[row], g[row], h[row]
		end
	else
		local output = {}
		function world_query_iter_next()
			local entity = entities[i]
			while entity == nil do
				lastArchetype = lastArchetype + 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i ~= 0 then
					entity = entities[i]
					columns = archetype.columns
					records = archetype.records
				end
			end

			local row = i
			i = i - 1

			for j, id in ids do
				output[j] = columns[records[id]][row]
			end

			return entity, unpack(output)
		end
	end

	local cached_query = query
	cached_query.archetypes = query_archetypes
	cached_query.__iter = cached_query_iter
	cached_query.iter = cached_query_iter
	setmetatable(cached_query, cached_query)
	return cached_query
end

local Query = {}
Query.__index = Query
Query.__iter = query_iter
Query.iter = query_iter_init
Query.without = query_without
Query.with = query_with
Query.archetypes = query_archetypes
Query.cached = query_cached

local function world_query(world, ...)
	local compatible_archetypes = {}
	local length = 0

	local ids = { ... }

	local archetypes = world.archetypes

	local idr
	local component_index = world.component_index

	local q = setmetatable({
		ids = ids,
		compatible_archetypes = compatible_archetypes,
		world = world,
	}, Query)

	for _, id in ipairs(ids) do
		local map = component_index[id]
		if not map then
			return q
		end

		if idr == nil or (map.size) < (idr.size) then
			idr = map
		end
	end

	if idr == nil then
		return q
	end

	for archetype_id in pairs(idr.cache) do
		local compatibleArchetype = archetypes[archetype_id]
		if #compatibleArchetype.entities ~= 0 then
			local records = compatibleArchetype.records
			local skip = false

			for i, id in ipairs(ids) do
				local tr = records[id]
				if not tr then
					skip = true
					break
				end
			end

			if not skip then
				length = length + 1
				compatible_archetypes[length] = compatibleArchetype
			end
		end
	end

	return q
end

local function world_each(world, id)
	local idr = world.component_index[id]
	if not idr then
		return NOOP
	end

	local idr_cache = idr.cache
	local archetypes = world.archetypes
	local archetype_id = next(idr_cache, nil)
	local archetype = archetypes[archetype_id]
	if not archetype then
		return NOOP
	end

	local entities = archetype.entities
	local row = #entities

	return function()
		local entity = entities[row]
		while not entity do
			archetype_id = next(idr_cache, archetype_id)
			if not archetype_id then
				return
			end
			archetype = archetypes[archetype_id]
			entities = archetype.entities
			row = #entities
			entity = entities[row]
		end
		row = row - 1
		return entity
	end
end

local function world_children(world, parent)
	return world_each(world, ECS_PAIR(EcsChildOf, parent))
end

local World = {}
World.__index = World

World.entity = world_entity
World.query = world_query
World.remove = world_remove
World.clear = world_clear
World.delete = world_delete
World.component = world_component
World.add = world_add
World.set = world_set
World.get = world_get
World.has = world_has
World.target = world_target
World.parent = world_parent
World.contains = world_contains
World.exists = world_exists
World.cleanup = world_cleanup
World.each = world_each
World.children = world_children
World.range = world_range

local function world_new()
	local entity_index = {
		dense_array = {},
		sparse_array = {},
		alive_count = 0,
		max_id = 0,
	}
	local self = setmetatable({
		archetype_edges = {},

		archetype_index = {},
		archetypes = {},
		component_index = {},
		entity_index = entity_index,
		ROOT_ARCHETYPE = nil,

		max_archetype_id = 0,
		max_component_id = ecs_max_component_id,

		observable = {},
	}, World)

	self.ROOT_ARCHETYPE = archetype_create(self, {}, "")

	for i = 1, HI_COMPONENT_ID do
		local e = entity_index_new_id(entity_index)
		world_add(self, e, EcsComponent)
	end

	for i = HI_COMPONENT_ID + 1, EcsRest do
		-- Initialize built-in components
		entity_index_new_id(entity_index)
	end

	world_add(self, EcsName, EcsComponent)
	world_add(self, EcsOnChange, EcsComponent)
	world_add(self, EcsOnAdd, EcsComponent)
	world_add(self, EcsOnRemove, EcsComponent)
	world_add(self, EcsWildcard, EcsComponent)
	world_add(self, EcsRest, EcsComponent)

	world_set(self, EcsOnAdd, EcsName, "jecs.OnAdd")
	world_set(self, EcsOnRemove, EcsName, "jecs.OnRemove")
	world_set(self, EcsOnChange, EcsName, "jecs.OnChange")
	world_set(self, EcsWildcard, EcsName, "jecs.Wildcard")
	world_set(self, EcsChildOf, EcsName, "jecs.ChildOf")
	world_set(self, EcsComponent, EcsName, "jecs.Component")
	world_set(self, EcsOnDelete, EcsName, "jecs.OnDelete")
	world_set(self, EcsOnDeleteTarget, EcsName, "jecs.OnDeleteTarget")
	world_set(self, EcsDelete, EcsName, "jecs.Delete")
	world_set(self, EcsRemove, EcsName, "jecs.Remove")
	world_set(self, EcsName, EcsName, "jecs.Name")
	world_set(self, EcsRest, EcsRest, "jecs.Rest")

	world_add(self, EcsChildOf, ECS_PAIR(EcsOnDeleteTarget, EcsDelete))

	for i = EcsRest + 1, ecs_max_tag_id do
		entity_index_new_id(entity_index)
	end

	for i, bundle in pairs(ecs_metadata) do
		for ty, value in bundle do
			if value == NULL then
				world_add(self, i, ty)
			else
				world_set(self, i, ty, value)
			end
		end
	end

	return self
end

World.new = world_new

-- type function ecs_id_t(entity)
-- 	local ty = entity:components()[2]
-- 	local __T = ty:readproperty(types.singleton("__T"))
-- 	if not __T then
-- 		return ty:readproperty(types.singleton("__jecs_pair_value"))
-- 	end
-- 	return __T
-- end

-- type function ecs_pair_t(first, second)
-- 	if ecs_id_t(first):is("nil") then
-- 		return second
-- 	else
-- 		return first
-- 	end
-- end
--

return {
	World = World,
	world = world_new,
	component = ECS_COMPONENT,
	tag = ECS_TAG,
	meta = ECS_META,
	is_tag = ecs_is_tag,
	OnAdd = EcsOnAdd,
	OnRemove = EcsOnRemove,
	OnChange = EcsOnChange,
	Wildcard = EcsWildcard,
	OnDelete = EcsOnDelete,
	OnDeleteTarget = EcsOnDeleteTarget,
	Delete = EcsDelete,
	Name = EcsName,
	Rest = EcsRest,
	pair = ECS_PAIR,
	-- Inwards facing API for testing
	ECS_ID = ECS_ENTITY_T_LO,
	ECS_GENERATION_INC = ECS_GENERATION_INC,
	ECS_GENERATION = ECS_GENERATION,
	ECS_ID_IS_WILDCARD = ECS_ID_IS_WILDCARD,
	ECS_ID_DELETE = ECS_ID_DELETE,
	ECS_META_RESET = ECS_META_RESET,

	-- IS_PAIR = (ECS_IS_PAIR :: any) :: <P, O>(pair: Pair<P, O>) -> boolean,
	-- ECS_PAIR_FIRST = ECS_PAIR_FIRST :: <P, O>(pair: Pair<P, O>) -> Id<P>,
	-- ECS_PAIR_SECOND = ECS_PAIR_SECOND :: <P, O>(pair: Pair<P, O>) -> Id<O>,
	-- pair_first = (ecs_pair_first :: any) :: <P, O>(world: World, pair: Pair<P, O>) -> Id<P>,
	-- pair_second = (ecs_pair_second :: any) :: <P, O>(world: World, pair: Pair<P, O>) -> Id<O>,
	entity_index_get_alive = entity_index_get_alive,

	archetype_append_to_records = archetype_append_to_records,
	id_record_ensure = id_record_ensure,
	archetype_create = archetype_create,
	archetype_ensure = archetype_ensure,
	find_insert = find_insert,
	find_archetype_with = find_archetype_with,
	find_archetype_without = find_archetype_without,
	create_edge_for_remove = create_edge_for_remove,
	archetype_traverse_add = archetype_traverse_add,
	archetype_traverse_remove = archetype_traverse_remove,

	entity_move = entity_move,

	entity_index_try_get = entity_index_try_get,
	entity_index_try_get_any = entity_index_try_get_any,
	entity_index_try_get_fast = entity_index_try_get_fast,
	entity_index_is_alive = entity_index_is_alive,
	entity_index_new_id = entity_index_new_id,

	query_iter = query_iter,
	query_iter_init = query_iter_init,
	query_with = query_with,
	query_without = query_without,
	query_archetypes = query_archetypes,
	query_match = query_match,

	find_observers = find_observers,
}
