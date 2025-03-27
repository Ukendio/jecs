--!optimize 2
--!native
--!strict
--draft 4

type i53 = number
type i24 = number

type Ty = { i53 }
type ArchetypeId = number

type Column = { any }

type Map<K, V> = { [K]: V }

type ecs_graph_edge_t = {
	from: ecs_archetype_t,
	to: ecs_archetype_t?,
	id: number,
	prev: ecs_graph_edge_t?,
	next: ecs_graph_edge_t?,
}

type ecs_graph_edges_t = Map<i53, ecs_graph_edge_t>

type ecs_graph_node_t = {
	add: ecs_graph_edges_t,
	remove: ecs_graph_edges_t,
	refs: ecs_graph_edge_t,
}

type ecs_archetype_t = {
	id: number,
	types: Ty,
	type: string,
	entities: { number },
	columns: { Column },
	records: { [i53]: number },
	counts: { [i53]: number },
} & ecs_graph_node_t

export type Archetype = {
	id: number,
	types: Ty,
	type: string,
	entities: { number },
	columns: { Column },
	records: { [Id]: number },
	counts: { [Id]: number },
}

type ecs_record_t = {
	archetype: ecs_archetype_t,
	row: number,
	dense: i24,
}

type ecs_id_record_t = {
	cache: { number },
	counts: { number },
	flags: number,
	size: number,
	hooks: {
		on_add: ((entity: i53) -> ())?,
		on_set: ((entity: i53, data: any) -> ())?,
		on_remove: ((entity: i53) -> ())?,
	},
}

type ecs_id_index_t = Map<i53, ecs_id_record_t>

type ecs_archetypes_map_t = { [string]: ecs_archetype_t }

type ecs_archetypes_t = { ecs_archetype_t }

type ecs_entity_index_t = {
	dense_array: Map<number, i53>,
	sparse_array: Map<i24, ecs_record_t>,
	alive_count: number,
	max_id: number,
}

type ecs_query_data_t = {
	compatible_archetypes: { ecs_archetype_t },
	ids: { i53 },
	filter_with: { i53 },
	filter_without: { i53 },
	next: () -> (number, ...any),
	world: ecs_world_t,
}

type ecs_observer_t = {
	callback: (archetype: ecs_archetype_t) -> (),
	query: ecs_query_data_t,
}

type ecs_observable_t = Map<i53, Map<i53, { ecs_observer_t }>>

type ecs_world_t = {
	entity_index: ecs_entity_index_t,
	component_index: ecs_id_index_t,
	archetypes: ecs_archetypes_t,
	archetype_index: ecs_archetypes_map_t,
	max_archetype_id: number,
	max_component_id: number,
	ROOT_ARCHETYPE: ecs_archetype_t,
	observable: Map<i53, Map<i53, { ecs_observer_t }>>,
}

local HI_COMPONENT_ID = _G.__JECS_HI_COMPONENT_ID or 256
-- stylua: ignore start
local EcsOnAdd =                    HI_COMPONENT_ID +  1
local EcsOnRemove =                 HI_COMPONENT_ID +  2
local EcsOnSet =                    HI_COMPONENT_ID +  3
local EcsWildcard =                 HI_COMPONENT_ID +  4
local EcsChildOf =                  HI_COMPONENT_ID +  5
local EcsComponent =                HI_COMPONENT_ID +  6
local EcsOnDelete =                 HI_COMPONENT_ID +  7
local EcsOnDeleteTarget =           HI_COMPONENT_ID +  8
local EcsDelete =                   HI_COMPONENT_ID +  9
local EcsRemove =                   HI_COMPONENT_ID + 10
local EcsName =                     HI_COMPONENT_ID + 11
local EcsOnArchetypeCreate =        HI_COMPONENT_ID + 12
local EcsOnArchetypeDelete =        HI_COMPONENT_ID + 13
local EcsRest =                     HI_COMPONENT_ID + 14

local ECS_ID_DELETE =                        0b0000_0001
local ECS_ID_IS_TAG =                        0b0000_0010
local ECS_ID_HAS_ON_ADD =                    0b0000_0100
local ECS_ID_HAS_ON_SET =                    0b0000_1000
local ECS_ID_HAS_ON_REMOVE =                 0b0001_0000
local ECS_ID_MASK =                          0b0000_0000

local ECS_ENTITY_MASK =              bit32.lshift(1, 24)
local ECS_GENERATION_MASK =          bit32.lshift(1, 16)

local NULL_ARRAY = table.freeze({})
local ECS_INTERNAL_ERROR = [[
	This is an internal error, please file a bug report via the following link:

	https://github.com/Ukendio/jecs/issues/new?template=BUG-REPORT.md
]]

local function ECS_COMBINE(id: number, generation: number): i53
	return id + (generation * ECS_ENTITY_MASK)
end
local ECS_PAIR_OFFSET = 2^48

local function ECS_IS_PAIR(e: number): boolean
	return e > ECS_PAIR_OFFSET
end

local function ECS_GENERATION_INC(e: i53): i53
	if e > ECS_ENTITY_MASK then
		local id = e % ECS_ENTITY_MASK
		local generation = e // ECS_ENTITY_MASK

		local next_gen = generation + 1
		if next_gen >= ECS_GENERATION_MASK then
			return id
		end

		return ECS_COMBINE(id, next_gen)
	end
	return ECS_COMBINE(e, 1)
end

local function ECS_ENTITY_T_LO(e: i53): i24
	return e % ECS_ENTITY_MASK
end

local function ECS_GENERATION(e: i53)
	return e // ECS_ENTITY_MASK
end

local function ECS_ENTITY_T_HI(e: i53): i24
	return e // ECS_ENTITY_MASK
end

local function ECS_PAIR(pred: i53, obj: i53): i53
	pred %= ECS_ENTITY_MASK
	obj %= ECS_ENTITY_MASK

	return obj + (pred * ECS_ENTITY_MASK) + ECS_PAIR_OFFSET
end

local function ECS_PAIR_FIRST(e: i53): i24
	return (e - ECS_PAIR_OFFSET) // ECS_ENTITY_MASK
end

local function ECS_PAIR_SECOND(e: i53): i24
	return (e - ECS_PAIR_OFFSET) % ECS_ENTITY_MASK
end

local function entity_index_try_get_any(
	entity_index: ecs_entity_index_t,
	entity: number
): ecs_record_t?
	local r = entity_index.sparse_array[ECS_ENTITY_T_LO(entity)]

	if not r or r.dense == 0 then
		return nil
	end

	return r
end

local function entity_index_try_get(entity_index: ecs_entity_index_t, entity: number): ecs_record_t?
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

local function entity_index_try_get_fast(entity_index: ecs_entity_index_t, entity: number): ecs_record_t?
	local r = entity_index.sparse_array[ECS_ENTITY_T_LO(entity)]
	if r then
		if entity_index.dense_array[r.dense] ~= entity then
			return nil
		end
	end
	return r
end

local function entity_index_is_alive(entity_index: ecs_entity_index_t, entity: i53)
	return entity_index_try_get(entity_index, entity) ~= nil
end

local function entity_index_get_alive(index: ecs_entity_index_t, entity: i53): i53?
	local r = entity_index_try_get_any(index, entity)
	if r then
		return index.dense_array[r.dense]
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

local function entity_index_new_id(entity_index: ecs_entity_index_t): i53
	local dense_array = entity_index.dense_array
	local alive_count = entity_index.alive_count
	local max_id = entity_index.max_id
	if alive_count ~= max_id then
		alive_count += 1
		entity_index.alive_count = alive_count
		local id = dense_array[alive_count]
		return id
	end

	local id = max_id + 1
	entity_index.max_id = id
	alive_count += 1
	entity_index.alive_count = alive_count
	dense_array[alive_count] = id
	entity_index.sparse_array[id] = { dense = alive_count } :: ecs_record_t

	return id
end

local function ecs_pair_first(world: ecs_world_t, e: i53)
	local pred = ECS_PAIR_FIRST(e)
	return ecs_get_alive(world, pred)
end

local function ecs_pair_second(world: ecs_world_t, e: i53)
	local obj = ECS_PAIR_SECOND(e)
	return ecs_get_alive(world, obj)
end

local function query_match(query: ecs_query_data_t,
	archetype: ecs_archetype_t)
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

local function find_observers(world: ecs_world_t, event: i53,
	component: i53): { ecs_observer_t }?
	local cache = world.observable[event]
	if not cache then
		return nil
	end
	return cache[component] :: any
end

local function archetype_move(
	entity_index: ecs_entity_index_t,
	to: ecs_archetype_t,
	dst_row: i24,
	from: ecs_archetype_t,
	src_row: i24
)
	local src_columns = from.columns
	local dst_columns = to.columns
	local dst_entities = to.entities
	local src_entities = from.entities

	local last = #src_entities
	local id_types = from.types
	local records = to.records

	for i, column in src_columns do
		if column == NULL_ARRAY then
			continue
		end
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

	local moved = #src_entities

	-- Move the entity from the source to the destination archetype.
	-- Because we have swapped columns we now have to update the records
	-- corresponding to the entities' rows that were swapped.
	local e1 = src_entities[src_row]
	local e2 = src_entities[moved]

	if src_row ~= moved then
		src_entities[src_row] = e2
	end

	src_entities[moved] = nil :: any
	dst_entities[dst_row] = e1

	local sparse_array = entity_index.sparse_array

	local record1 = sparse_array[ECS_ENTITY_T_LO(e1)]
	local record2 = sparse_array[ECS_ENTITY_T_LO(e2)]
	record1.row = dst_row
	record2.row = src_row
end

local function archetype_append(
	entity: i53,
	archetype: ecs_archetype_t
): number
	local entities = archetype.entities
	local length = #entities + 1
	entities[length] = entity
	return length
end

local function new_entity(
	entity: i53,
	record: ecs_record_t,
	archetype: ecs_archetype_t
): ecs_record_t
	local row = archetype_append(entity, archetype)
	record.archetype = archetype
	record.row = row
	return record
end

local function entity_move(
	entity_index: ecs_entity_index_t,
	entity: i53,
	record: ecs_record_t,
	to: ecs_archetype_t
)
	local sourceRow = record.row
	local from = record.archetype
	local dst_row = archetype_append(entity, to)
	archetype_move(entity_index, to, dst_row, from, sourceRow)
	record.archetype = to
	record.row = dst_row
end

local function hash(arr: { number }): string
	return table.concat(arr, "_")
end

local function fetch(id: i53, records: { number },
	columns: { Column }, row: number): any
	local tr = records[id]

	if not tr then
		return nil
	end

	return columns[tr][row]
end

local function world_get(world: ecs_world_t, entity: i53,
	a: i53, b: i53?, c: i53?, d: i53?, e: i53?): ...any
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

local function world_has_one_inline(world: ecs_world_t, entity: i53, id: i53): boolean
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

local function world_has(world: ecs_world_t, entity: i53, ...: i53): boolean
	local record = entity_index_try_get_fast(world.entity_index, entity)
	if not record then
		return false
	end

	local archetype = record.archetype
	if not archetype then
		return false
	end

	local records = archetype.records

	for i = 1, select("#", ...) do
		if not records[select(i, ...)] then
			return false
		end
	end

	return true
end

local function world_target(world: ecs_world_t, entity: i53, relation: i24, index: number?): i24?
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

local function ECS_ID_IS_WILDCARD(e: i53): boolean
	local first = ECS_ENTITY_T_HI(e)
	local second = ECS_ENTITY_T_LO(e)
	return first == EcsWildcard or second == EcsWildcard
end

local function id_record_ensure(world: ecs_world_t, id: number): ecs_id_record_t
	local component_index = world.component_index
	local entity_index = world.entity_index
	local idr: ecs_id_record_t = component_index[id]

	if not idr then
		local flags = ECS_ID_MASK
		local relation = id
		local target = 0
		local is_pair = ECS_IS_PAIR(id)
		if is_pair then
			relation = entity_index_get_alive(entity_index, ECS_PAIR_FIRST(id)) :: i53
			assert(relation and entity_index_is_alive(
				entity_index, relation), ECS_INTERNAL_ERROR)
			target = entity_index_get_alive(entity_index, ECS_PAIR_SECOND(id)) :: i53
			assert(target and entity_index_is_alive(
				entity_index, target), ECS_INTERNAL_ERROR)
		end

		local cleanup_policy = world_target(world, relation, EcsOnDelete, 0)
		local cleanup_policy_target = world_target(world, relation, EcsOnDeleteTarget, 0)

		local has_delete = false

		if cleanup_policy == EcsDelete or cleanup_policy_target == EcsDelete then
			has_delete = true
		end

		local on_add, on_set, on_remove = world_get(world, relation, EcsOnAdd, EcsOnSet, EcsOnRemove)

		local is_tag = not world_has_one_inline(world, relation, EcsComponent)

		if is_tag and is_pair then
			is_tag = not world_has_one_inline(world, target, EcsComponent)
		end

		flags = bit32.bor(
			flags,
			if on_add then ECS_ID_HAS_ON_ADD else 0,
			if on_remove then ECS_ID_HAS_ON_REMOVE else 0,
			if on_set then ECS_ID_HAS_ON_SET else 0,
			if has_delete then ECS_ID_DELETE else 0,
			if is_tag then ECS_ID_IS_TAG else 0
		)

		idr = {
			size = 0,
			cache = {},
			counts = {},
			flags = flags,
			hooks = {
				on_add = on_add,
				on_set = on_set,
				on_remove = on_remove,
			},
		}

		component_index[id] = idr
	end

	return idr
end

local function archetype_append_to_records(
	idr: ecs_id_record_t,
	archetype: ecs_archetype_t,
	id: i53,
	index: number
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

local function archetype_create(world: ecs_world_t, id_types: { i24 }, ty, prev: i53?): ecs_archetype_t
	local archetype_id = (world.max_archetype_id :: number) + 1
	world.max_archetype_id = archetype_id

	local length = #id_types
	local columns = (table.create(length) :: any) :: { Column }

	local records: { number } = {}
	local counts: {number} = {}

	local archetype: ecs_archetype_t = {
		columns = columns,
		entities = {},
		id = archetype_id,
		records = records,
		counts = counts,
		type = ty,
		types = id_types,

		add = {},
		remove = {},
		refs = {} :: ecs_graph_edge_t,
	}

	for i, component_id in id_types do
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

		if bit32.band(idr.flags, ECS_ID_IS_TAG) == 0 then
			columns[i] = {}
		else
			columns[i] = NULL_ARRAY
		end
	end

	for id in records do
		local observer_list = find_observers(world, EcsOnArchetypeCreate, id)
		if not observer_list then
			continue
		end
		for _, observer in observer_list do
			if query_match(observer.query, archetype) then
				observer.callback(archetype)
			end
		end
	end

	world.archetype_index[ty] = archetype
	world.archetypes[archetype_id] = archetype

	return archetype
end

local function world_entity(world: ecs_world_t): i53
	return entity_index_new_id(world.entity_index)
end

local function world_parent(world: ecs_world_t, entity: i53)
	return world_target(world, entity, EcsChildOf, 0)
end

local function archetype_ensure(world: ecs_world_t, id_types): ecs_archetype_t
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

local function find_insert(id_types: { i53 }, toAdd: i53): number
	for i, id in id_types do
		if id == toAdd then
			return -1
		end
		if id > toAdd then
			return i
		end
	end
	return #id_types + 1
end

local function find_archetype_with(world: ecs_world_t, node: ecs_archetype_t, id: i53): ecs_archetype_t
	local id_types = node.types
	-- Component IDs are added incrementally, so inserting and sorting
	-- them each time would be expensive. Instead this insertion sort can find the insertion
	-- point in the types array.

	local dst = table.clone(node.types) :: { i53 }
	local at = find_insert(id_types, id)
	if at == -1 then
		-- If it finds a duplicate, it just means it is the same archetype so it can return it
		-- directly instead of needing to hash types for a lookup to the archetype.
		return node
	end
	table.insert(dst, at, id)

	return archetype_ensure(world, dst)
end

local function find_archetype_without(
	world: ecs_world_t,
	node: ecs_archetype_t,
	id: i53
): ecs_archetype_t
	local id_types = node.types
	local at = table.find(id_types, id)
	if at == nil then
		return node
	end

	local dst = table.clone(id_types)
	table.remove(dst, at)

	return archetype_ensure(world, dst)
end

local function archetype_init_edge(
	archetype: ecs_archetype_t,
	edge: ecs_graph_edge_t,
	id: i53,
	to: ecs_archetype_t
)
	edge.from = archetype
	edge.to = to
	edge.id = id
end

local function archetype_ensure_edge(
	world: ecs_world_t,
	edges: ecs_graph_edges_t,
	id: i53
): ecs_graph_edge_t
	local edge = edges[id]
	if not edge then
		edge = {} :: ecs_graph_edge_t
		edges[id] = edge
	end

	return edge
end

local function init_edge_for_add(world, archetype: ecs_archetype_t, edge: ecs_graph_edge_t, id, to: ecs_archetype_t)
	archetype_init_edge(archetype, edge, id, to)
	archetype_ensure_edge(world, archetype.add, id)
	if archetype ~= to then
		local to_refs = to.refs
		local next_edge = to_refs.next

		to_refs.next = edge
		edge.prev = to_refs
		edge.next = next_edge

		if next_edge then
			next_edge.prev = edge
		end
	end
end

local function init_edge_for_remove(
	world: ecs_world_t,
	archetype: ecs_archetype_t,
	edge: ecs_graph_edge_t,
	id: number,
	to: ecs_archetype_t
)
	archetype_init_edge(archetype, edge, id, to)
	archetype_ensure_edge(world, archetype.remove, id)
	if archetype ~= to then
		local to_refs = to.refs
		local prev_edge = to_refs.prev

		to_refs.prev = edge
		edge.next = to_refs
		edge.prev = prev_edge

		if prev_edge then
			prev_edge.next = edge
		end
	end
end

local function create_edge_for_add(
	world: ecs_world_t,
	node: ecs_archetype_t,
	edge: ecs_graph_edge_t,
	id: i53
): ecs_archetype_t
	local to = find_archetype_with(world, node, id)
	init_edge_for_add(world, node, edge, id, to)
	return to
end

local function create_edge_for_remove(
	world: ecs_world_t,
	node: ecs_archetype_t,
	edge: ecs_graph_edge_t,
	id: i53
): ecs_archetype_t
	local to = find_archetype_without(world, node, id)
	init_edge_for_remove(world, node, edge, id, to)
	return to
end

local function archetype_traverse_add(
	world: ecs_world_t,
	id: i53,
	from: ecs_archetype_t
): ecs_archetype_t
	from = from or world.ROOT_ARCHETYPE
	local edge = archetype_ensure_edge(world, from.add, id)

	local to = edge.to
	if not to then
		to = create_edge_for_add(world, from, edge, id)
	end

	return to :: ecs_archetype_t
end

local function archetype_traverse_remove(
	world: ecs_world_t,
	id: i53,
	from: ecs_archetype_t
): ecs_archetype_t
	from = from or world.ROOT_ARCHETYPE

	local edge = archetype_ensure_edge(world, from.remove, id)

	local to = edge.to
	if not to then
		to = create_edge_for_remove(world, from, edge, id)
	end

	return to :: ecs_archetype_t
end

local function world_add(
	world: ecs_world_t,
	entity: i53,
	id: i53
): ()
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
		on_add(entity)
	end
end

local function world_set(world: ecs_world_t, entity: i53, id: i53, data: unknown): ()
	local entity_index = world.entity_index
	local record = entity_index_try_get_fast(entity_index, entity)
	if not record then
		return
	end

	local from: ecs_archetype_t = record.archetype
	local to: ecs_archetype_t = archetype_traverse_add(world, id, from)
	local idr = world.component_index[id]
	local idr_hooks = idr.hooks

	if from == to then
		-- If the archetypes are the same it can avoid moving the entity
		-- and just set the data directly.
		local tr = to.records[id]
		local column = from.columns[tr]
		column[record.row] = data
		local on_set = idr_hooks.on_set
		if on_set then
			on_set(entity, data)
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
		on_add(entity)
	end

	local on_set = idr_hooks.on_set
	if on_set then
		on_set(entity, data)
	end
end

local function world_component(world: World): i53
	local id = (world.max_component_id :: number) + 1
	if id > HI_COMPONENT_ID then
		-- IDs are partitioned into ranges because component IDs are not nominal,
		-- so it needs to error when IDs intersect into the entity range.
		error("Too many components, consider using world:entity() instead to create components.")
	end
	world.max_component_id = id

	return id
end

local function world_remove(world: ecs_world_t, entity: i53, id: i53)
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
			on_remove(entity)
		end

		local to = archetype_traverse_remove(world, id, record.archetype)

		entity_move(entity_index, entity, record, to)
	end
end

local function archetype_fast_delete_last(columns: { Column }, column_count: number, types: { i53 }, entity: i53)
	for i, column in columns do
		if column ~= NULL_ARRAY then
			column[column_count] = nil
		end
	end
end

local function archetype_fast_delete(columns: { Column }, column_count: number, row, types, entity)
	for i, column in columns do
		if column ~= NULL_ARRAY then
			column[row] = column[column_count]
			column[column_count] = nil
		end
	end
end

local function archetype_delete(world: ecs_world_t, archetype: ecs_archetype_t, row: number)
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

	for _, id in id_types do
		local idr = component_index[id]
		local on_remove = idr.hooks.on_remove
		if on_remove then
			on_remove(delete)
		end
	end

	entities[last] = nil :: any

	if row == last then
		archetype_fast_delete_last(columns, column_count, id_types, delete)
	else
		archetype_fast_delete(columns, column_count, row, id_types, delete)
	end
end

local function world_clear(world: ecs_world_t, entity: i53)
	--TODO: use sparse_get (stashed)
	local record = entity_index_try_get(world.entity_index, entity)
	if not record then
		return
	end

	local archetype = record.archetype
	local row = record.row

	local idr = world.component_index[entity]
	if idr then
		local count = 0
		local queue = {}
		for archetype_id in idr.cache do
			local idr_archetype = world.archetypes[archetype_id]
			local entities = idr_archetype.entities
			local n = #entities
			count += n
			table.move(entities, 1, n, #queue + 1, queue)
		end
		for _, e in queue do
			world_remove(world, e, entity)
		end
	end

	if archetype then
		-- In the future should have a destruct mode for
		-- deleting archetypes themselves. Maybe requires recycling
		archetype_delete(world, archetype, row)
	end

	record.archetype = nil :: any
	record.row = nil :: any
end

local function archetype_disconnect_edge(edge: ecs_graph_edge_t)
	local edge_next = edge.next
	local edge_prev = edge.prev
	if edge_next then
		edge_next.prev = edge_prev
	end
	if edge_prev then
		edge_prev.next = edge_next
	end
end

local function archetype_remove_edge(edges: ecs_graph_edges_t, id: i53, edge: ecs_graph_edge_t)
	archetype_disconnect_edge(edge)
	edges[id] = nil :: any
end

local function archetype_clear_edges(archetype: ecs_archetype_t)
	local add: ecs_graph_edges_t = archetype.add
	local remove: ecs_graph_edges_t = archetype.remove
	local node_refs = archetype.refs
	for id, edge in add do
		archetype_disconnect_edge(edge)
		add[id] = nil :: any
	end
	for id, edge in remove do
		archetype_disconnect_edge(edge)
		remove[id] = nil :: any
	end

	local cur = node_refs.next
	while cur do
		local edge = cur :: ecs_graph_edge_t
		local next_edge = edge.next
		archetype_remove_edge(edge.from.add, edge.id, edge)
		cur = next_edge
	end

	cur = node_refs.prev
	while cur do
		local edge: ecs_graph_edge_t = cur
		local next_edge = edge.prev
		archetype_remove_edge(edge.from.remove, edge.id, edge)
		cur = next_edge
	end

	node_refs.next = nil
	node_refs.prev = nil
end

local function archetype_destroy(world: ecs_world_t, archetype: ecs_archetype_t)
	if archetype == world.ROOT_ARCHETYPE then
		return
	end

	local component_index = world.component_index
	archetype_clear_edges(archetype)
	local archetype_id = archetype.id
	world.archetypes[archetype_id] = nil :: any
	world.archetype_index[archetype.type] = nil :: any
	local records = archetype.records

	for id in records do
		local observer_list = find_observers(world, EcsOnArchetypeDelete, id)
		if not observer_list then
			continue
		end
		for _, observer in observer_list do
			if query_match(observer.query, archetype) then
				observer.callback(archetype)
			end
		end
	end

	for id in records do
		local idr = component_index[id]
		idr.cache[archetype_id] = nil :: any
		idr.counts[archetype_id] = nil
		idr.size -= 1
		records[id] = nil :: any
		if idr.size == 0 then
			component_index[id] = nil :: any
		end
	end
end

local function world_cleanup(world: ecs_world_t)
	local archetypes = world.archetypes

	for _, archetype in archetypes do
		if #archetype.entities == 0 then
			archetype_destroy(world, archetype)
		end
	end

	local new_archetypes = table.create(#archetypes) :: { ecs_archetype_t }
	local new_archetype_map = {}

	for index, archetype in archetypes do
		new_archetypes[index] = archetype
		new_archetype_map[archetype.type] = archetype
	end

	world.archetypes = new_archetypes
	world.archetype_index = new_archetype_map
end

local function world_delete(world: ecs_world_t, entity: i53)
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
	local idr_t = component_index[tgt]
	local idr = component_index[delete]

	if idr then
		local flags = idr.flags
		if bit32.band(flags, ECS_ID_DELETE) ~= 0 then
			for archetype_id in idr.cache do
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

	local dense_array = entity_index.dense_array

	if idr_t then
		local children
		local ids
		local count = 0
		local archetype_ids = idr_t.cache
		for archetype_id in archetype_ids do
			local idr_t_archetype = archetypes[archetype_id]
			local idr_t_types = idr_t_archetype.types
			local entities = idr_t_archetype.entities
			local removal_queued = false

			for _, id in idr_t_types do
				if not ECS_IS_PAIR(id) then
					continue
				end
				local object = entity_index_get_alive(
				    entity_index, ECS_PAIR_SECOND(id))
				if object ~= delete then
					continue
				end
				local id_record = component_index[id]
				local flags = id_record.flags
				local flags_delete_mask: number = bit32.band(flags, ECS_ID_DELETE)
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

			if not removal_queued then
				continue
			end
			if not children then
				children = {}
			end
			local n = #entities
			table.move(entities, 1, n, count + 1, children)
			count += n
		end

		if ids then
			for id in ids do
				for _, child in children do
					world_remove(world, child, id)
				end
			end
		end

		for archetype_id in archetype_ids do
			archetype_destroy(world, archetypes[archetype_id])
		end
	end

	local index_of_deleted_entity = record.dense
	local index_of_last_alive_entity = entity_index.alive_count
	entity_index.alive_count = index_of_last_alive_entity - 1

	local last_alive_entity = dense_array[index_of_last_alive_entity]
	local r_swap = entity_index_try_get_any(entity_index, last_alive_entity) :: ecs_record_t
	r_swap.dense = index_of_deleted_entity
	record.archetype = nil :: any
	record.row = nil :: any
	record.dense = index_of_last_alive_entity

	dense_array[index_of_deleted_entity] = last_alive_entity
	dense_array[index_of_last_alive_entity] = ECS_GENERATION_INC(entity)
end

local function world_contains(world: ecs_world_t, entity): boolean
	return entity_index_is_alive(world.entity_index, entity)
end

local function NOOP() end

export type QueryInner = {
	compatible_archetypes: { Archetype },
	ids: { i53 },
	filter_with: { i53 },
	filter_without: { i53 },
	next: () -> (number, ...any),
	world: World,
}



local function query_iter_init(query: ecs_query_data_t): () -> (number, ...any)
	local world_query_iter_next

	local compatible_archetypes = query.compatible_archetypes
	local lastArchetype = 1
	local archetype = compatible_archetypes[1]
	if not archetype then
		return NOOP :: () -> (number, ...any)
	end
	local columns = archetype.columns
	local entities = archetype.entities
	local i = #entities
	local records = archetype.records

	local ids = query.ids
	local A, B, C, D, E, F, G, H, I = unpack(ids)
	local a: Column, b: Column, c: Column, d: Column
	local e: Column, f: Column, g: Column, h: Column

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
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns = archetype.columns
				records = archetype.records
				a = columns[records[A]]
			end

			local row = i
			i -= 1

			return entity, a[row]
		end
	elseif not C then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns = archetype.columns
				records = archetype.records
				a = columns[records[A]]
				b = columns[records[B]]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row]
		end
	elseif not D then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns = archetype.columns
				records = archetype.records
				a = columns[records[A]]
				b = columns[records[B]]
				c = columns[records[C]]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row]
		end
	elseif not E then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns = archetype.columns
				records = archetype.records
				a = columns[records[A]]
				b = columns[records[B]]
				c = columns[records[C]]
				d = columns[records[D]]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row]
		end
	elseif not F then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns = archetype.columns
				records = archetype.records
				a = columns[records[A]]
				b = columns[records[B]]
				c = columns[records[C]]
				d = columns[records[D]]
				e = columns[records[E]]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row], e[row]
		end
	elseif not G then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
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

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row], e[row], f[row]
		end
	elseif not H then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
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

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row], e[row], f[row], g[row]
		end
	elseif not I then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
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

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row], e[row], f[row], g[row], h[row]
		end
	else
		local output = {}
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns = archetype.columns
				records = archetype.records
			end

			local row = i
			i -= 1

			for j, id in ids do
				output[j] = columns[records[id]][row]
			end

			return entity, unpack(output)
		end
	end

	query.next = world_query_iter_next
	return world_query_iter_next
end

local function query_iter(query): () -> (number, ...any)
	local query_next = query.next
	if not query_next then
		query_next = query_iter_init(query)
	end
	return query_next
end

local function query_without(query: ecs_query_data_t, ...: i53)
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

		if matches then
			continue
		end

		local last = #compatible_archetypes
		if last ~= i then
			compatible_archetypes[i] = compatible_archetypes[last]
		end
		compatible_archetypes[last] = nil :: any
	end

	return query :: any
end

local function query_with(query: ecs_query_data_t, ...: i53)
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

		if matches then
			continue
		end

		local last = #compatible_archetypes
		if last ~= i then
			compatible_archetypes[i] = compatible_archetypes[last]
		end
		compatible_archetypes[last] = nil :: any
	end

	return query :: any
end

-- Meant for directly iterating over archetypes to minimize
-- function call overhead. Should not be used unless iterating over
-- hundreds of thousands of entities in bulk.
local function query_archetypes(query)
	return query.compatible_archetypes
end

local function query_cached(query: ecs_query_data_t)
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
	local a: Column, b: Column, c: Column, d: Column
	local e: Column, f: Column, g: Column, h: Column

	local world_query_iter_next
	local columns: { Column }
	local entities: { number }
	local i: number
	local archetype: ecs_archetype_t
	local records: { number }
	local archetypes = query.compatible_archetypes

	local world = query.world :: { observable: ecs_observable_t }
	-- Only need one observer for EcsArchetypeCreate and EcsArchetypeDelete respectively
	-- because the event will be emitted for all components of that Archetype.
	local observable = world.observable :: ecs_observable_t
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
		local i = table.find(archetypes, archetype) :: number
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
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns = archetype.columns
				records = archetype.records
				a = columns[records[A]]
			end

			local row = i
			i -= 1

			return entity, a[row]
		end
	elseif not C then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns = archetype.columns
				records = archetype.records
				a = columns[records[A]]
				b = columns[records[B]]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row]
		end
	elseif not D then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns = archetype.columns
				records = archetype.records
				a = columns[records[A]]
				b = columns[records[B]]
				c = columns[records[C]]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row]
		end
	elseif not E then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns = archetype.columns
				records = archetype.records
				a = columns[records[A]]
				b = columns[records[B]]
				c = columns[records[C]]
				d = columns[records[D]]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row]
		end
	elseif not F then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns = archetype.columns
				records = archetype.records
				a = columns[records[A]]
				b = columns[records[B]]
				c = columns[records[C]]
				d = columns[records[D]]
				e = columns[records[E]]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row], e[row]
		end
	elseif not G then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
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

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row], e[row], f[row]
		end
	elseif not H then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
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

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row], e[row], f[row], g[row]
		end
	elseif not I then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
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

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row], e[row], f[row], g[row], h[row]
		end
	else
		local queryOutput = {}
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns = archetype.columns
				records = archetype.records
			end

			local row = i
			i -= 1

			if not F then
				return entity, a[row], b[row], c[row], d[row], e[row]
			elseif not G then
				return entity, a[row], b[row], c[row], d[row], e[row], f[row]
			elseif not H then
				return entity, a[row], b[row], c[row], d[row], e[row], f[row], g[row]
			elseif not I then
				return entity, a[row], b[row], c[row], d[row], e[row], f[row], g[row], h[row]
			end

			for j, id in ids do
				queryOutput[j] = columns[records[id]][row]
			end

			return entity, unpack(queryOutput)
		end
	end

	local cached_query = query :: any
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

local function world_query(world: ecs_world_t, ...)
	local compatible_archetypes = {}
	local length = 0

	local ids = { ... }

	local archetypes = world.archetypes

	local idr: ecs_id_record_t?
	local component_index = world.component_index

	local q = setmetatable({
		ids = ids,
		compatible_archetypes = compatible_archetypes,
		world = world,
	}, Query)

	for _, id in ids do
		local map = component_index[id]
		if not map then
			return q
		end

		if idr == nil or map.size < idr.size then
			idr = map
		end
	end

	if not idr then
		return q
	end

	for archetype_id in idr.cache do
		local compatibleArchetype = archetypes[archetype_id]
		if #compatibleArchetype.entities == 0 then
			continue
		end
		local records = compatibleArchetype.records

		local skip = false

		for i, id in ids do
			local tr = records[id]
			if not tr then
				skip = true
				break
			end
		end

		if skip then
			continue
		end

		length += 1
		compatible_archetypes[length] = compatibleArchetype
	end

	return q
end

local function world_each(world: ecs_world_t, id: i53): () -> ()
	local idr = world.component_index[id]
	if not idr then
		return NOOP
	end

	local idr_cache = idr.cache
	local archetypes = world.archetypes
	local archetype_id = next(idr_cache, nil) :: number
	local archetype = archetypes[archetype_id]
	if not archetype then
		return NOOP
	end

	local entities = archetype.entities
	local row = #entities

	return function(): any
		local entity = entities[row]
		while not entity do
			archetype_id = next(idr_cache, archetype_id) :: number
			if not archetype_id then
				return
			end
			archetype = archetypes[archetype_id]
			entities = archetype.entities
			row = #entities
			entity = entities[row]
		end
		row -= 1
		return entity
	end
end

local function world_children(world: ecs_world_t, parent: i53)
	return world_each(world, ECS_PAIR(EcsChildOf, parent))
end

export type Record = {
	archetype: Archetype,
	row: number,
	dense: i24,
}
export type ComponentRecord = {
	cache: { [Id]: number },
	counts: { [Id]: number },
	flags: number,
	size: number,
	hooks: {
		on_add: ((entity: Entity) -> ())?,
		on_set: ((entity: Entity, data: any) -> ())?,
		on_remove: ((entity: Entity) -> ())?,
	},
}
export type ComponentIndex = Map<Id, ComponentRecord>
export type Archetypes = { [Id]: Archetype }

export type EntityIndex = {
	dense_array: Map<number, Entity>,
	sparse_array: Map<i24, Record>,
	alive_count: number,
	max_id: number,
}

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
World.cleanup = world_cleanup
World.each = world_each
World.children = world_children

local function world_new()
	local entity_index = {
		dense_array = {},
		sparse_array = {},
		alive_count = 0,
		max_id = 0,
	} :: ecs_entity_index_t
	local self = setmetatable({
		archetype_index = {} :: { [string]: Archetype },
		archetypes = {} :: Archetypes,
		component_index = {} :: ComponentIndex,
		entity_index = entity_index,
		ROOT_ARCHETYPE = (nil :: any) :: Archetype,

		max_archetype_id = 0,
		max_component_id = 0,

		observable = {} :: Observable,
	}, World) :: any

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
	world_add(self, EcsOnSet, EcsComponent)
	world_add(self, EcsOnAdd, EcsComponent)
	world_add(self, EcsOnRemove, EcsComponent)
	world_add(self, EcsWildcard, EcsComponent)
	world_add(self, EcsRest, EcsComponent)

	world_set(self, EcsOnAdd, EcsName, "jecs.OnAdd")
	world_set(self, EcsOnRemove, EcsName, "jecs.OnRemove")
	world_set(self, EcsOnSet, EcsName, "jecs.OnSet")
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

	return self
end

World.new = world_new

export type Entity<T = unknown> = { __T: T }
export type Id<T = unknown> = { __T: T }
export type Pair<P, O> = Id<P>
type ecs_id_t<T=unknown> = Id<T> | Pair<T, "Tag"> | Pair<"Tag", T>
export type Item<T...> = (self: Query<T...>) -> (Entity, T...)
export type Iter<T...> = (query: Query<T...>) -> () -> (Entity, T...)

export type Query<T...> = typeof(setmetatable({}, {
	__iter = (nil :: any) :: Iter<T...>,
})) & {
	iter: Iter<T...>,
	with: (self: Query<T...>, ...Id) -> Query<T...>,
	without: (self: Query<T...>, ...Id) -> Query<T...>,
	archetypes: (self: Query<T...>) -> { Archetype },
	cached: (self: Query<T...>) -> Query<T...>,
}

export type Observer = {
 	callback: (archetype: Archetype) -> (),
   	query: QueryInner,
}

export type Observable = {
	[Id]: {
		[Id]: {
			{ Observer }
		}
	}
}

export type World = {
	archetype_index: { [string]: Archetype },
	archetypes: Archetypes,
	component_index: ComponentIndex,
	entity_index: EntityIndex,
	ROOT_ARCHETYPE: Archetype,

	max_component_id: number,
	max_archetype_id: number,

	observable: any,

	--- Creates a new entity
	entity: (self: World, id: Entity?) -> Entity,
	--- Creates a new entity located in the first 256 ids.
	--- These should be used for static components for fast access.
	component: <T>(self: World) -> Entity<T>,
	--- Gets the target of an relationship. For example, when a user calls
	--- `world:target(id, ChildOf(parent), 0)`, you will obtain the parent entity.
	target: (self: World, id: Entity, relation: Id, index: number?) -> Entity?,
	--- Deletes an entity and all it's related components and relationships.
	delete: (self: World, id: Entity) -> (),

	--- Adds a component to the entity with no value
	add: <T>(self: World, id: Entity, component: Id) -> (),
	--- Assigns a value to a component on the given entity
	set: <T>(self: World, id: Entity, component: Id<T>, data: T) -> (),

	cleanup: (self: World) -> (),
	-- Clears an entity from the world
	clear: (self: World, id: Entity) -> (),
	--- Removes a component from the given entity
	remove: (self: World, id: Entity, component: Id) -> (),
	--- Retrieves the value of up to 4 components. These values may be nil.
	get: (<A>(self: World, id: Entity, Id<A>) -> A?)
		& (<A, B>(self: World, id: Entity, Id<A>, Id<B>) -> (A?, B?))
		& (<A, B, C>(self: World, id: Entity, Id<A>, Id<B>, Id<C>) -> (A?, B?, C?))
		& <A, B, C, D>(self: World, id: Entity, Id<A>, Id<B>, Id<C>, Id<D>) -> (A?, B?, C?, D?),

	--- Returns whether the entity has the ID.
	has: (self: World, entity: Entity, ...Id) -> boolean,

	--- Get parent (target of ChildOf relationship) for entity. If there is no ChildOf relationship pair, it will return nil.
	parent:(self: World, entity: Entity) -> Entity,

	--- Checks if the world contains the given entity
	contains:(self: World, entity: Entity) -> boolean,

	each: (self: World, id: Id) -> () -> Entity,

	children: (self: World, id: Id) -> () -> Entity,

	--- Searches the world for entities that match a given query
	query: (<A>(World, Id<A>) -> Query<A>)
		& (<A, B>(World, Id<A>, Id<B>) -> Query<A, B>)
		& (<A, B, C>(World, Id<A>, Id<B>, Id<C>) -> Query<A, B, C>)
		& (<A, B, C, D>(World, Id<A>, Id<B>, Id<C>, Id<D>) -> Query<A, B, C, D>)
		& (<A, B, C, D, E>(World, Id<A>, Id<B>, Id<C>, Id<D>, Id<E>) -> Query<A, B, C, D, E>)
		& (<A, B, C, D, E, F>(World, Id<A>, Id<B>, Id<C>, Id<D>, Id<E>, Id<F>) -> Query<A, B, C, D, E, F>)
		& (<A, B, C, D, E, F, G>(World, Id<A>, Id<B>, Id<C>, Id<D>, Id<E>, Id<F>, Id<G>) -> Query<A, B, C, D, E, F, G>)
		& (<A, B, C, D, E, F, G, H>(World, Id<A>, Id<B>, Id<C>, Id<D>, Id<E>, Id<F>, Id<G>, Id<H>, ...Id<any>) -> Query<A, B, C, D, E, F, G, H>)
}
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

return {
	World = World :: { new: () -> World },
	world = World.new :: () -> World,

	OnAdd = EcsOnAdd :: Entity<(entity: Entity) -> ()>,
	OnRemove = EcsOnRemove :: Entity<(entity: Entity) -> ()>,
	OnSet = EcsOnSet :: Entity<(entity: Entity, data: any) -> ()>,
	ChildOf = EcsChildOf :: Entity,
	Component = EcsComponent :: Entity,
	Wildcard = EcsWildcard :: Entity,
	w = EcsWildcard :: Entity,
	OnDelete = EcsOnDelete :: Entity,
	OnDeleteTarget = EcsOnDeleteTarget :: Entity,
	Delete = EcsDelete :: Entity,
	Remove = EcsRemove :: Entity,
	Name = EcsName :: Entity<string>,
	Rest = EcsRest :: Entity,

	pair = (ECS_PAIR :: any) :: <P, O>(first: Id<P>, second: Id<O>) -> Pair<P, O>,

	-- Inwards facing API for testing
	ECS_ID = ECS_ENTITY_T_LO,
	ECS_GENERATION_INC = ECS_GENERATION_INC,
	ECS_GENERATION = ECS_GENERATION,
	ECS_ID_IS_WILDCARD = ECS_ID_IS_WILDCARD,

	ECS_ID_DELETE = ECS_ID_DELETE,

	IS_PAIR = ECS_IS_PAIR,
	pair_first = ecs_pair_first,
	pair_second = ecs_pair_second,
	entity_index_get_alive = entity_index_get_alive,

	archetype_append_to_records = archetype_append_to_records,
	id_record_ensure = id_record_ensure,
	archetype_create = archetype_create,
	archetype_ensure = archetype_ensure,
	find_insert = find_insert,
	find_archetype_with = find_archetype_with,
	find_archetype_without = find_archetype_without,
	archetype_init_edge = archetype_init_edge,
	archetype_ensure_edge = archetype_ensure_edge,
	init_edge_for_add = init_edge_for_add,
	init_edge_for_remove = init_edge_for_remove,
	create_edge_for_add = create_edge_for_add,
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
