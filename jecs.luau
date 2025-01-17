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

type GraphEdge = {
	from: Archetype,
	to: Archetype?,
	id: number,
	prev: GraphEdge?,
	next: GraphEdge?,
}

type GraphEdges = Map<i53, GraphEdge>

type GraphNode = {
	add: GraphEdges,
	remove: GraphEdges,
	refs: GraphEdge,
}

export type Archetype = {
	id: number,
	types: Ty,
	type: string,
	entities: { number },
	columns: { Column },
	records: { ArchetypeRecord },
} & GraphNode

export type Record = {
	archetype: Archetype,
	row: number,
	dense: i24,
}

type ArchetypeRecord = {
	count: number,
	column: number,
}

type IdRecord = {
	cache: { ArchetypeRecord },
	flags: number,
	size: number,
	hooks: {
		on_add: ((entity: i53) -> ())?,
		on_set: ((entity: i53, data: any) -> ())?,
		on_remove: ((entity: i53) -> ())?,
	},
}

type ComponentIndex = Map<i53, IdRecord>

type Archetypes = { [ArchetypeId]: Archetype }

type ArchetypeDiff = {
	added: Ty,
	removed: Ty,
}

type EntityIndex = {
	dense_array: Map<i24, i53>,
	sparse_array: Map<i53, Record>,
	alive_count: number,
	max_id: number,
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

local ECS_PAIR_FLAG =                                0x8
local ECS_ID_FLAGS_MASK =                           0x10
local ECS_ENTITY_MASK =              bit32.lshift(1, 24)
local ECS_GENERATION_MASK =          bit32.lshift(1, 16)

local ECS_ID_DELETE =                        0b0000_0001
local ECS_ID_IS_TAG =                        0b0000_0010
local ECS_ID_HAS_ON_ADD =                    0b0000_0100
local ECS_ID_HAS_ON_SET =                    0b0000_1000
local ECS_ID_HAS_ON_REMOVE =                 0b0001_0000
local ECS_ID_MASK =                          0b0000_0000
-- stylua: ignore end
local NULL_ARRAY = table.freeze({}) :: Column

local function FLAGS_ADD(is_pair: boolean): number
	local flags = 0x0

	if is_pair then
		flags = bit32.bor(flags, ECS_PAIR_FLAG) -- HIGHEST bit in the ID.
	end
	if false then
		flags = bit32.bor(flags, 0x4) -- Set the second flag to true
	end
	if false then
		flags = bit32.bor(flags, 0x2) -- Set the third flag to true
	end
	if false then
		flags = bit32.bor(flags, 0x1) -- LAST BIT in the ID.
	end

	return flags
end

local function ECS_COMBINE(source: number, target: number): i53
	return (source * 268435456) + (target * ECS_ID_FLAGS_MASK)
end

local function ECS_IS_PAIR(e: number): boolean
	return if e > ECS_ENTITY_MASK then (e % ECS_ID_FLAGS_MASK) // ECS_PAIR_FLAG ~= 0 else false
end

-- HIGH 24 bits LOW 24 bits
local function ECS_GENERATION(e: i53): i24
	return if e > ECS_ENTITY_MASK then (e // ECS_ID_FLAGS_MASK) % ECS_GENERATION_MASK else 0
end

local function ECS_GENERATION_INC(e: i53)
	if e > ECS_ENTITY_MASK then
		local flags = e // ECS_ID_FLAGS_MASK
		local id = flags // ECS_ENTITY_MASK
		local generation = flags % ECS_GENERATION_MASK

		local next_gen = generation + 1
		if next_gen > ECS_GENERATION_MASK then
			return id
		end

		return ECS_COMBINE(id, next_gen)
	end
	return ECS_COMBINE(e, 1)
end

-- FIRST gets the high ID
local function ECS_ENTITY_T_HI(e: i53): i24
	return if e > ECS_ENTITY_MASK then (e // ECS_ID_FLAGS_MASK) % ECS_ENTITY_MASK else e
end

-- SECOND
local function ECS_ENTITY_T_LO(e: i53): i24
	return if e > ECS_ENTITY_MASK then (e // ECS_ID_FLAGS_MASK) // ECS_ENTITY_MASK else e
end

local function _STRIP_GENERATION(e: i53): i24
	return ECS_ENTITY_T_LO(e)
end

local function ECS_PAIR(pred: i53, obj: i53): i53
	return ECS_COMBINE(ECS_ENTITY_T_LO(pred), ECS_ENTITY_T_LO(obj)) + FLAGS_ADD(--[[isPair]] true) :: i53
end

local function entity_index_try_get_any(entity_index: EntityIndex, entity: number): Record?
	local r = entity_index.sparse_array[ECS_ENTITY_T_LO(entity)]
	if not r then
		return nil
	end

	if not r or r.dense == 0 then
		return nil
	end

	return r
end

local function entity_index_try_get(entity_index: EntityIndex, entity: number): Record?
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

local function entity_index_try_get_fast(entity_index: EntityIndex, entity: number): Record?
	local r = entity_index.sparse_array[ECS_ENTITY_T_LO(entity)]
	if r then
		if entity_index.dense_array[r.dense] ~= entity then
			return nil
		end
	end
	return r
end

local function entity_index_get_alive(index: EntityIndex, e: i24): i53
	local r = entity_index_try_get_any(index, e)
	if r then
		return index.dense_array[r.dense]
	end
	return 0
end

local function entity_index_is_alive(entity_index: EntityIndex, entity: number)
	return entity_index_try_get(entity_index, entity) ~= nil
end

local function entity_index_new_id(entity_index: EntityIndex): i53
	local dense_array = entity_index.dense_array
	local alive_count = entity_index.alive_count
	if alive_count ~= #dense_array then
		alive_count += 1
		entity_index.alive_count = alive_count
		local id = dense_array[alive_count]
		return id
	end

	local id = entity_index.max_id + 1
	entity_index.max_id = id
	alive_count += 1
	entity_index.alive_count = alive_count
	dense_array[alive_count] = id
	entity_index.sparse_array[id] = { dense = alive_count } :: Record

	return id
end

-- ECS_PAIR_FIRST, gets the relationship target / obj / HIGH bits
local function ecs_pair_first(world, e)
	return entity_index_get_alive(world.entity_index, ECS_ENTITY_T_LO(e))
end

-- ECS_PAIR_SECOND gets the relationship / pred / LOW bits
local function ecs_pair_second(world, e)
	return entity_index_get_alive(world.entity_index, ECS_ENTITY_T_HI(e))
end

local function query_match(query, archetype: Archetype)
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

local function find_observers(world: World, event, component): { Observer }?
	local cache = world.observerable[event]
	if not cache then
		return nil
	end
	return cache[component] :: any
end

local function archetype_move(entity_index: EntityIndex, to: Archetype, dst_row: i24, from: Archetype, src_row: i24)
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
			dst_columns[tr.column][dst_row] = column[src_row]
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

local function archetype_append(entity: number, archetype: Archetype): number
	local entities = archetype.entities
	local length = #entities + 1
	entities[length] = entity
	return length
end

local function new_entity(entityId: i53, record: Record, archetype: Archetype): Record
	local row = archetype_append(entityId, archetype)
	record.archetype = archetype
	record.row = row
	return record
end

local function entity_move(entity_index: EntityIndex, entityId: i53, record: Record, to: Archetype)
	local sourceRow = record.row
	local from = record.archetype
	local dst_row = archetype_append(entityId, to)
	archetype_move(entity_index, to, dst_row, from, sourceRow)
	record.archetype = to
	record.row = dst_row
end

local function hash(arr: { number }): string
	return table.concat(arr, "_")
end

local function fetch(id, records: { ArchetypeRecord }, columns: { Column }, row: number): any
	local tr = records[id]

	if not tr then
		return nil
	end

	return columns[tr.column][row]
end

local function world_get(world: World, entity: i53, a: i53, b: i53?, c: i53?, d: i53?, e: i53?): ...any
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

local function world_get_one_inline(world: World, entity: i53, id: i53): any
	local record = entity_index_try_get_fast(world.entity_index, entity)
	if not record then
		return nil
	end

	local archetype = record.archetype
	if not archetype then
		return nil
	end

	local tr = archetype.records[id]
	if not tr then
		return nil
	end
	return archetype.columns[tr.column][record.row]
end

local function world_has_one_inline(world: World, entity: number, id: i53): boolean
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

local function world_has(world: World, entity: number, ...: i53): boolean
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

local function world_target(world: World, entity: i53, relation: i24, index: number?): i24?
	local nth = index or 0
	local record = entity_index_try_get_fast(world.entity_index, entity)
	if not record then
		return nil
	end

	local archetype = record.archetype
	if not archetype then
		return nil
	end

	local idr = world.componentIndex[ECS_PAIR(relation, EcsWildcard)]
	if not idr then
		return nil
	end

	local tr = idr.cache[archetype.id]
	if not tr then
		return nil
	end

	local count = tr.count
	if nth >= count then
		nth = nth + count + 1
	end

	nth = archetype.types[nth + tr.column]

	if not nth then
		return nil
	end

	return ecs_pair_second(world, nth)
end

local function ECS_ID_IS_WILDCARD(e: i53): boolean
	local first = ECS_ENTITY_T_HI(e)
	local second = ECS_ENTITY_T_LO(e)
	return first == EcsWildcard or second == EcsWildcard
end

local function id_record_ensure(world: World, id: number): IdRecord
	local componentIndex = world.componentIndex
	local idr: IdRecord = componentIndex[id]

	if not idr then
		local flags = ECS_ID_MASK
		local relation = id
		local is_pair = ECS_IS_PAIR(id)
		if is_pair then
			relation = ecs_pair_first(world, id)
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
			is_tag = not world_has_one_inline(world, ecs_pair_second(world, id), EcsComponent)
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
			flags = flags,
			hooks = {
				on_add = on_add,
				on_set = on_set,
				on_remove = on_remove,
			},
		}

		componentIndex[id] = idr
	end

	return idr
end

local function archetype_append_to_records(
	idr: IdRecord,
	archetype_id: number,
	records: Map<i53, ArchetypeRecord>,
	id: number,
	index: number
)
	local tr = idr.cache[archetype_id]
	if not tr then
		tr = { column = index, count = 1 }
		idr.cache[archetype_id] = tr
		idr.size += 1
		records[id] = tr
	else
		tr.count += 1
	end
end

local function archetype_create(world: World, id_types: { i24 }, ty, prev: i53?): Archetype
	local archetype_id = (world.nextArchetypeId :: number) + 1
	world.nextArchetypeId = archetype_id

	local length = #id_types
	local columns = (table.create(length) :: any) :: { Column }

	local records: { ArchetypeRecord } = {}

	local archetype: Archetype = {
		columns = columns,
		entities = {},
		id = archetype_id,
		records = records,
		type = ty,
		types = id_types,

		add = {},
		remove = {},
		refs = {} :: GraphEdge,
	}

	for i, componentId in id_types do
		local idr = id_record_ensure(world, componentId)
		archetype_append_to_records(idr, archetype_id, records, componentId, i)

		if ECS_IS_PAIR(componentId) then
			local relation = ecs_pair_first(world, componentId)
			local object = ecs_pair_second(world, componentId)

			local r = ECS_PAIR(relation, EcsWildcard)
			local idr_r = id_record_ensure(world, r)
			archetype_append_to_records(idr_r, archetype_id, records, r, i)

			local t = ECS_PAIR(EcsWildcard, object)
			local idr_t = id_record_ensure(world, t)
			archetype_append_to_records(idr_t, archetype_id, records, t, i)
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

	world.archetypeIndex[ty] = archetype
	world.archetypes[archetype_id] = archetype

	return archetype
end

local function world_entity(world: World): i53
	return entity_index_new_id(world.entity_index)
end

local function world_parent(world: World, entity: i53)
	return world_target(world, entity, EcsChildOf, 0)
end

local function archetype_ensure(world: World, id_types): Archetype
	if #id_types < 1 then
		return world.ROOT_ARCHETYPE
	end

	local ty = hash(id_types)
	local archetype = world.archetypeIndex[ty]
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

local function find_archetype_with(world: World, node: Archetype, id: i53): Archetype
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

local function find_archetype_without(world: World, node: Archetype, id: i53): Archetype
	local id_types = node.types
	local at = table.find(id_types, id)
	if at == nil then
		return node
	end

	local dst = table.clone(id_types)
	table.remove(dst, at)

	return archetype_ensure(world, dst)
end

local function archetype_init_edge(archetype: Archetype, edge: GraphEdge, id: i53, to: Archetype)
	edge.from = archetype
	edge.to = to
	edge.id = id
end

local function archetype_ensure_edge(world, edges: GraphEdges, id): GraphEdge
	local edge = edges[id]
	if not edge then
		edge = {} :: GraphEdge
		edges[id] = edge
	end

	return edge
end

local function init_edge_for_add(world, archetype: Archetype, edge: GraphEdge, id, to: Archetype)
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

local function init_edge_for_remove(world: World, archetype: Archetype, edge: GraphEdge, id: number, to: Archetype)
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

local function create_edge_for_add(world: World, node: Archetype, edge: GraphEdge, id: i53): Archetype
	local to = find_archetype_with(world, node, id)
	init_edge_for_add(world, node, edge, id, to)
	return to
end

local function create_edge_for_remove(world: World, node: Archetype, edge: GraphEdge, id: i53): Archetype
	local to = find_archetype_without(world, node, id)
	init_edge_for_remove(world, node, edge, id, to)
	return to
end

local function archetype_traverse_add(world: World, id: i53, from: Archetype): Archetype
	from = from or world.ROOT_ARCHETYPE
	local edge = archetype_ensure_edge(world, from.add, id)

	local to = edge.to
	if not to then
		to = create_edge_for_add(world, from, edge, id)
	end

	return to :: Archetype
end

local function archetype_traverse_remove(world: World, id: i53, from: Archetype): Archetype
	from = from or world.ROOT_ARCHETYPE

	local edge = archetype_ensure_edge(world, from.remove, id)

	local to = edge.to
	if not to then
		to = create_edge_for_remove(world, from, edge, id)
	end

	return to :: Archetype
end

local function invoke_hook(action, entity, data)
	action(entity, data)
end

local function world_add(world: World, entity: i53, id: i53): ()
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

	local idr = world.componentIndex[id]
	local on_add = idr.hooks.on_add

	if on_add then
		on_add(entity)
	end
end

local function world_set(world: World, entity: i53, id: i53, data: unknown): ()
	local entity_index = world.entity_index
	local record = entity_index_try_get_fast(entity_index, entity)
	if not record then
		return
	end

	local from: Archetype = record.archetype
	local to: Archetype = archetype_traverse_add(world, id, from)
	local idr = world.componentIndex[id]
	local flags = idr.flags
	local is_tag = bit32.band(flags, ECS_ID_IS_TAG) ~= 0
	local idr_hooks = idr.hooks

	if from == to then
		if is_tag then
			return
		end
		-- If the archetypes are the same it can avoid moving the entity
		-- and just set the data directly.
		local tr = to.records[id]
		local column = from.columns[tr.column]
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

	local on_add = idr_hooks.on_add
	if on_add then
		on_add(entity)
	end

	if is_tag then
		return
	end

	local tr = to.records[id]
	local column = to.columns[tr.column]

	column[record.row] = data

	local on_set = idr_hooks.on_set
	if on_set then
		invoke_hook(on_set, entity, data)
	end
end

local function world_component(world: World): i53
	local componentId = (world.nextComponentId :: number) + 1
	if componentId > HI_COMPONENT_ID then
		-- IDs are partitioned into ranges because component IDs are not nominal,
		-- so it needs to error when IDs intersect into the entity range.
		error("Too many components, consider using world:entity() instead to create components.")
	end
	world.nextComponentId = componentId

	return componentId
end

local function world_remove(world: World, entity: i53, id: i53)
	local entity_index = world.entity_index
	local record = entity_index_try_get_fast(entity_index, entity)
	if not record then
		return
	end
	local from = record.archetype

	if not from then
		return
	end
	local to = archetype_traverse_remove(world, id, from)

	if from and not (from == to) then
		local idr = world.componentIndex[id]
		local on_remove = idr.hooks.on_remove
		if on_remove then
			on_remove(entity)
		end

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

local function archetype_delete(world: World, archetype: Archetype, row: number, destruct: boolean?)
	local entityIndex = world.entity_index
	local columns = archetype.columns
	local id_types = archetype.types
	local entities = archetype.entities
	local column_count = #entities
	local last = #entities
	local move = entities[last]
	local delete = entities[row]
	entities[row] = move
	entities[last] = nil :: any

	if row ~= last then
		-- TODO: should be "entity_index_sparse_get(entityIndex, move)"
		local record_to_move = entity_index_try_get_any(entityIndex, move)
		if record_to_move then
			record_to_move.row = row
		end
	end

	-- TODO: if last == 0 then deactivate table

	local component_index = world.componentIndex
	for _, id in id_types do
		local idr = component_index[id]
		local on_remove = idr.hooks.on_remove
		if on_remove then
			on_remove(delete)
		end
	end

	if row == last then
		archetype_fast_delete_last(columns, column_count, id_types, delete)
	else
		archetype_fast_delete(columns, column_count, row, id_types, delete)
	end
end

local function world_clear(world: World, entity: i53)
	--TODO: use sparse_get (stashed)
	local record = entity_index_try_get(world.entity_index, entity)
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

	record.archetype = nil :: any
	record.row = nil :: any
end

local function archetype_disconnect_edge(edge: GraphEdge)
	local edge_next = edge.next
	local edge_prev = edge.prev
	if edge_next then
		edge_next.prev = edge_prev
	end
	if edge_prev then
		edge_prev.next = edge_next
	end
end

local function archetype_remove_edge(edges: Map<i53, GraphEdge>, id: i53, edge: GraphEdge)
	archetype_disconnect_edge(edge)
	edges[id] = nil :: any
end

local function archetype_clear_edges(archetype: Archetype)
	local add: GraphEdges = archetype.add
	local remove: GraphEdges = archetype.remove
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
		local edge = cur :: GraphEdge
		local next_edge = edge.next
		archetype_remove_edge(edge.from.add, edge.id, edge)
		cur = next_edge
	end

	cur = node_refs.prev
	while cur do
		local edge: GraphEdge = cur
		local next_edge = edge.prev
		archetype_remove_edge(edge.from.remove, edge.id, edge)
		cur = next_edge
	end

	node_refs.next = nil
	node_refs.prev = nil
end

local function archetype_destroy(world: World, archetype: Archetype)
	if archetype == world.ROOT_ARCHETYPE then
		return
	end

	local component_index = world.componentIndex
	archetype_clear_edges(archetype)
	local archetype_id = archetype.id
	world.archetypes[archetype_id] = nil :: any
	world.archetypeIndex[archetype.type] = nil :: any
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
		idr.size -= 1
		records[id] = nil :: any
		if idr.size == 0 then
			component_index[id] = nil :: any
		end
	end
end

local function world_cleanup(world: World)
	local archetypes = world.archetypes

	for _, archetype in archetypes do
		if #archetype.entities == 0 then
			archetype_destroy(world, archetype)
		end
	end

	local new_archetypes = table.create(#archetypes) :: { Archetype }
	local new_archetype_map = {}

	for index, archetype in archetypes do
		new_archetypes[index] = archetype
		new_archetype_map[archetype.type] = archetype
	end

	world.archetypes = new_archetypes
	world.archetypeIndex = new_archetype_map
end

local world_delete: (world: World, entity: i53, destruct: boolean?) -> ()
do
	function world_delete(world: World, entity: i53, destruct: boolean?)
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
			archetype_delete(world, archetype, row, destruct)
		end

		local delete = entity
		local component_index = world.componentIndex
		local archetypes: Archetypes = world.archetypes
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
				end
			else
				for archetype_id in idr.cache do
					local idr_archetype = archetypes[archetype_id]
					local entities = idr_archetype.entities
					local n = #entities
					for i = n, 1, -1 do
						world_remove(world, entities[i], delete)
					end
				end

				for archetype_id in idr.cache do
					local idr_archetype = archetypes[archetype_id]
					archetype_destroy(world, idr_archetype)
				end
			end
		end

		if idr_t then
			for archetype_id in idr_t.cache do
				local children = {}
				local idr_t_archetype = archetypes[archetype_id]

				local idr_t_types = idr_t_archetype.types

				for _, child in idr_t_archetype.entities do
					table.insert(children, child)
				end

				for _, id in idr_t_types do
					if not ECS_IS_PAIR(id) then
						continue
					end
					local object = ecs_pair_second(world, id)
					if object == delete then
						local id_record = component_index[id]
						local flags = id_record.flags
						local flags_delete_mask: number = bit32.band(flags, ECS_ID_DELETE)
						if flags_delete_mask ~= 0 then
							for _, child in children do
								-- Cascade deletions of it has Delete as component trait
								world_delete(world, child, destruct)
							end
							break
						else
							local on_remove = id_record.hooks.on_remove
							local to = archetype_traverse_remove(world, id, idr_t_archetype)
							if on_remove then
								for _, child in children do
									on_remove(child)
									local r = entity_index_try_get_fast(entity_index, child) :: Record
									entity_move(entity_index, child, r, to)
								end
							else
								for _, child in children do
									local r = entity_index_try_get_fast(entity_index, child) :: Record
									entity_move(entity_index, child, r, to)
								end
							end
						end
					end
				end

				archetype_destroy(world, idr_t_archetype)
			end
		end

		local dense_array = entity_index.dense_array
		local index_of_deleted_entity = record.dense
		local index_of_last_alive_entity = entity_index.alive_count
		entity_index.alive_count = index_of_last_alive_entity - 1

		local last_alive_entity = dense_array[index_of_last_alive_entity]
		local r_swap = entity_index_try_get_any(entity_index, last_alive_entity) :: Record
		r_swap.dense = index_of_deleted_entity
		record.archetype = nil :: any
		record.row = nil :: any
		record.dense = index_of_last_alive_entity

		dense_array[index_of_deleted_entity] = last_alive_entity
		dense_array[index_of_last_alive_entity] = ECS_GENERATION_INC(entity)
	end
end

local function world_contains(world: World, entity): boolean
	return entity_index_is_alive(world.entity_index, entity)
end

local function NOOP() end

local function ARM(query, ...)
	return query
end

local EMPTY_LIST = {}
local EMPTY_QUERY = {
	__iter = function()
		return NOOP
	end,
	iter = function()
		return NOOP
	end,
	with = ARM,
	without = ARM,
	archetypes = function()
		return EMPTY_LIST
	end,
}

setmetatable(EMPTY_QUERY, EMPTY_QUERY)

type QueryInner = {
	compatible_archetypes: { Archetype },
	ids: { i53 },
	filter_with: { i53 },
	filter_without: { i53 },
	next: () -> (number, ...any),
	world: World,
}

local function query_iter_init(query: QueryInner): () -> (number, ...any)
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
		a = columns[records[A].column]
	elseif not C then
		a = columns[records[A].column]
		b = columns[records[B].column]
	elseif not D then
		a = columns[records[A].column]
		b = columns[records[B].column]
		c = columns[records[C].column]
	elseif not E then
		a = columns[records[A].column]
		b = columns[records[B].column]
		c = columns[records[C].column]
		d = columns[records[D].column]
	elseif not F then
		a = columns[records[A].column]
		b = columns[records[B].column]
		c = columns[records[C].column]
		d = columns[records[D].column]
		e = columns[records[E].column]
	elseif not G then
		a = columns[records[A].column]
		b = columns[records[B].column]
		c = columns[records[C].column]
		d = columns[records[D].column]
		e = columns[records[E].column]
		f = columns[records[F].column]
	elseif not H then
		a = columns[records[A].column]
		b = columns[records[B].column]
		c = columns[records[C].column]
		d = columns[records[D].column]
		e = columns[records[E].column]
		f = columns[records[F].column]
		g = columns[records[G].column]
	elseif not I then
		a = columns[records[A].column]
		b = columns[records[B].column]
		c = columns[records[C].column]
		d = columns[records[D].column]
		e = columns[records[E].column]
		f = columns[records[F].column]
		g = columns[records[G].column]
		h = columns[records[H].column]
	end

	if not B then
		function world_query_iter_next(): any
			local entityId = entities[i]
			while entityId == nil do
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
				entityId = entities[i]
				columns = archetype.columns
				records = archetype.records
				a = columns[records[A].column]
			end

			local row = i
			i -= 1

			return entityId, a[row]
		end
	elseif not C then
		function world_query_iter_next(): any
			local entityId = entities[i]
			while entityId == nil do
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
				entityId = entities[i]
				columns = archetype.columns
				records = archetype.records
				a = columns[records[A].column]
				b = columns[records[B].column]
			end

			local row = i
			i -= 1

			return entityId, a[row], b[row]
		end
	elseif not D then
		function world_query_iter_next(): any
			local entityId = entities[i]
			while entityId == nil do
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
				entityId = entities[i]
				columns = archetype.columns
				records = archetype.records
				a = columns[records[A].column]
				b = columns[records[B].column]
				c = columns[records[C].column]
			end

			local row = i
			i -= 1

			return entityId, a[row], b[row], c[row]
		end
	elseif not E then
		function world_query_iter_next(): any
			local entityId = entities[i]
			while entityId == nil do
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
				entityId = entities[i]
				columns = archetype.columns
				records = archetype.records
				a = columns[records[A].column]
				b = columns[records[B].column]
				c = columns[records[C].column]
				d = columns[records[D].column]
			end

			local row = i
			i -= 1

			return entityId, a[row], b[row], c[row], d[row]
		end
	else
		local queryOutput = {}
		function world_query_iter_next(): any
			local entityId = entities[i]
			while entityId == nil do
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
				entityId = entities[i]
				columns = archetype.columns
				records = archetype.records

				if not F then
					a = columns[records[A].column]
					b = columns[records[B].column]
					c = columns[records[C].column]
					d = columns[records[D].column]
					e = columns[records[E].column]
				elseif not G then
					a = columns[records[A].column]
					b = columns[records[B].column]
					c = columns[records[C].column]
					d = columns[records[D].column]
					e = columns[records[E].column]
					f = columns[records[F].column]
				elseif not H then
					a = columns[records[A].column]
					b = columns[records[B].column]
					c = columns[records[C].column]
					d = columns[records[D].column]
					e = columns[records[E].column]
					f = columns[records[F].column]
					g = columns[records[G].column]
				elseif not I then
					a = columns[records[A].column]
					b = columns[records[B].column]
					c = columns[records[C].column]
					d = columns[records[D].column]
					e = columns[records[E].column]
					f = columns[records[F].column]
					g = columns[records[G].column]
					h = columns[records[H].column]
				end
			end

			local row = i
			i -= 1

			if not F then
				return entityId, a[row], b[row], c[row], d[row], e[row]
			elseif not G then
				return entityId, a[row], b[row], c[row], d[row], e[row], f[row]
			elseif not H then
				return entityId, a[row], b[row], c[row], d[row], e[row], f[row], g[row]
			elseif not I then
				return entityId, a[row], b[row], c[row], d[row], e[row], f[row], g[row], h[row]
			end

			for j, id in ids do
				queryOutput[j] = columns[records[id].column][row]
			end

			return entityId, unpack(queryOutput)
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

local function query_without(query: QueryInner, ...: i53)
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

local function query_with(query: QueryInner, ...: i53)
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

local function query_cached(query: QueryInner)
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
	local archetype: Archetype
	local records: { ArchetypeRecord }
	local archetypes = query.compatible_archetypes

	local world = query.world :: World
	-- Only need one observer for EcsArchetypeCreate and EcsArchetypeDelete respectively
	-- because the event will be emitted for all components of that Archetype.
	local observerable = world.observerable
	local on_create_action = observerable[EcsOnArchetypeCreate]
	if not on_create_action then
		on_create_action = {}
		observerable[EcsOnArchetypeCreate] = on_create_action
	end
	local query_cache_on_create = on_create_action[A]
	if not query_cache_on_create then
		query_cache_on_create = {}
		on_create_action[A] = query_cache_on_create
	end

	local on_delete_action = observerable[EcsOnArchetypeDelete]
	if not on_delete_action then
		on_delete_action = {}
		observerable[EcsOnArchetypeDelete] = on_delete_action
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
		local i = table.find(archetypes, archetype)  :: number
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
			a = columns[records[A].column]
		elseif not C then
			a = columns[records[A].column]
			b = columns[records[B].column]
		elseif not D then
			a = columns[records[A].column]
			b = columns[records[B].column]
			c = columns[records[C].column]
		elseif not E then
			a = columns[records[A].column]
			b = columns[records[B].column]
			c = columns[records[C].column]
			d = columns[records[D].column]
		elseif not F then
			a = columns[records[A].column]
			b = columns[records[B].column]
			c = columns[records[C].column]
			d = columns[records[D].column]
			e = columns[records[E].column]
		elseif not G then
			a = columns[records[A].column]
			b = columns[records[B].column]
			c = columns[records[C].column]
			d = columns[records[D].column]
			e = columns[records[E].column]
			f = columns[records[F].column]
		elseif not H then
			a = columns[records[A].column]
			b = columns[records[B].column]
			c = columns[records[C].column]
			d = columns[records[D].column]
			e = columns[records[E].column]
			f = columns[records[F].column]
			g = columns[records[G].column]
		elseif not I then
			a = columns[records[A].column]
			b = columns[records[B].column]
			c = columns[records[C].column]
			d = columns[records[D].column]
			e = columns[records[E].column]
			f = columns[records[F].column]
			g = columns[records[G].column]
			h = columns[records[H].column]
		end

		return world_query_iter_next
	end

	if not B then
		function world_query_iter_next(): any
			local entityId = entities[i]
			while entityId == nil do
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
				entityId = entities[i]
				columns = archetype.columns
				records = archetype.records
				a = columns[records[A].column]
			end

			local row = i
			i -= 1

			return entityId, a[row]
		end
	elseif not C then
		function world_query_iter_next(): any
			local entityId = entities[i]
			while entityId == nil do
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
				entityId = entities[i]
				columns = archetype.columns
				records = archetype.records
				a = columns[records[A].column]
				b = columns[records[B].column]
			end

			local row = i
			i -= 1

			return entityId, a[row], b[row]
		end
	elseif not D then
		function world_query_iter_next(): any
			local entityId = entities[i]
			while entityId == nil do
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
				entityId = entities[i]
				columns = archetype.columns
				records = archetype.records
				a = columns[records[A].column]
				b = columns[records[B].column]
				c = columns[records[C].column]
			end

			local row = i
			i -= 1

			return entityId, a[row], b[row], c[row]
		end
	elseif not E then
		function world_query_iter_next(): any
			local entityId = entities[i]
			while entityId == nil do
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
				entityId = entities[i]
				columns = archetype.columns
				records = archetype.records
				a = columns[records[A].column]
				b = columns[records[B].column]
				c = columns[records[C].column]
				d = columns[records[D].column]
			end

			local row = i
			i -= 1

			return entityId, a[row], b[row], c[row], d[row]
		end
	else
		local queryOutput = {}
		function world_query_iter_next(): any
			local entityId = entities[i]
			while entityId == nil do
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
				entityId = entities[i]
				columns = archetype.columns
				records = archetype.records

				if not F then
					a = columns[records[A].column]
					b = columns[records[B].column]
					c = columns[records[C].column]
					d = columns[records[D].column]
					e = columns[records[E].column]
				elseif not G then
					a = columns[records[A].column]
					b = columns[records[B].column]
					c = columns[records[C].column]
					d = columns[records[D].column]
					e = columns[records[E].column]
					f = columns[records[F].column]
				elseif not H then
					a = columns[records[A].column]
					b = columns[records[B].column]
					c = columns[records[C].column]
					d = columns[records[D].column]
					e = columns[records[E].column]
					f = columns[records[F].column]
					g = columns[records[G].column]
				elseif not I then
					a = columns[records[A].column]
					b = columns[records[B].column]
					c = columns[records[C].column]
					d = columns[records[D].column]
					e = columns[records[E].column]
					f = columns[records[F].column]
					g = columns[records[G].column]
					h = columns[records[H].column]
				end
			end

			local row = i
			i -= 1

			if not F then
				return entityId, a[row], b[row], c[row], d[row], e[row]
			elseif not G then
				return entityId, a[row], b[row], c[row], d[row], e[row], f[row]
			elseif not H then
				return entityId, a[row], b[row], c[row], d[row], e[row], f[row], g[row]
			elseif not I then
				return entityId, a[row], b[row], c[row], d[row], e[row], f[row], g[row], h[row]
			end

			for j, id in ids do
				queryOutput[j] = columns[records[id].column][row]
			end

			return entityId, unpack(queryOutput)
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

local function world_query(world: World, ...)
	local compatible_archetypes = {}
	local length = 0

	local ids = { ... }

	local archetypes = world.archetypes

	local idr: IdRecord?
	local componentIndex = world.componentIndex

	local q = setmetatable({
		ids = ids,
		compatible_archetypes = compatible_archetypes,
		world = world,
	}, Query)

	for _, id in ids do
		local map = componentIndex[id]
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

local function world_each(world: World, id): () -> ()
	local idr = world.componentIndex[id]
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
World.cleanup = world_cleanup
World.each = world_each
World.children = world_children

if _G.__JECS_DEBUG then
	local function dbg_info(n: number): any
		return debug.info(n, "s")
	end
	local function throw(msg: string)
		local s = 1
		local root = dbg_info(1)
		repeat
			s += 1
		until dbg_info(s) ~= root
		if warn then
			error(msg, s)
		else
			print(`[jecs] error: {msg}\n`)
		end
	end

	local function ASSERT<T>(v: T, msg: string)
		if v then
			return
		end
		throw(msg)
	end

	local function get_name(world, id)
		return world_get_one_inline(world, id, EcsName)
	end

	local function bname(world: World, id): string
		local name: string
		if ECS_IS_PAIR(id) then
			local first = get_name(world, ecs_pair_first(world, id))
			local second = get_name(world, ecs_pair_second(world, id))
			name = `pair({first}, {second})`
		else
			return get_name(world, id)
		end
		if name then
			return name
		else
			return `${id}`
		end
	end

	local function ID_IS_TAG(world: World, id)
		if ECS_IS_PAIR(id) then
			id = ecs_pair_first(world, id)
		end
		return not world_has_one_inline(world, id, EcsComponent)
	end

	World.query = function(world: World, ...)
		ASSERT((...), "Requires at least a single component")
		return world_query(world, ...)
	end

	World.set = function(world: World, entity: i53, id: i53, value: any): ()
		local is_tag = ID_IS_TAG(world, id)
		if is_tag and value == nil then
			local _1 = bname(world, entity)
			local _2 = bname(world, id)
			local why = "cannot set component value to nil"
			throw(why)
			return
		elseif value ~= nil and is_tag then
			local _1 = bname(world, entity)
			local _2 = bname(world, id)
			local why = `cannot set a component value because {_2} is a tag`
			why ..= `\n[jecs] note: consider using "world:add({_1}, {_2})" instead`
			throw(why)
			return
		end

		world_set(world, entity, id, value)
	end

	World.add = function(world: World, entity: i53, id: i53, value: any)
		if value ~= nil then
			local _1 = bname(world, entity)
			local _2 = bname(world, id)
			throw("You provided a value when none was expected. " .. `Did you mean to use "world:add({_1}, {_2})"`)
		end

		world_add(world, entity, id)
	end

	World.get = function(world: World, entity: i53, ...)
		local length = select("#", ...)
		ASSERT(length < 5, "world:get does not support more than 4 components")
		local _1
		for i = 1, length do
			local id = select(i, ...)
			local id_is_tag = not world_has(world, id, EcsComponent)
			if id_is_tag then
				local name = get_name(world, id)
				if not _1 then
					_1 = get_name(world, entity)
				end
				throw(
					`cannot get (#{i}) component {name} value because it is a tag.`
						.. `\n[jecs] note: If this was intentional, use "world:has({_1}, {name}) instead"`
				)
			end
		end

		return world_get(world, entity, ...)
	end
end

function World.new()
	local entity_index: EntityIndex = {
		dense_array = {} :: { [i24]: i53 },
		sparse_array = {} :: { [i53]: Record },
		alive_count = 0,
		max_id = 0,
	}
	local self = setmetatable({
		archetypeIndex = {} :: { [string]: Archetype },
		archetypes = {} :: Archetypes,
		componentIndex = {} :: ComponentIndex,
		entity_index = entity_index,
		nextArchetypeId = 0 :: number,
		nextComponentId = 0 :: number,
		nextEntityId = 0 :: number,
		ROOT_ARCHETYPE = (nil :: any) :: Archetype,
		observerable = {},
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

export type Id<T = nil> =
    | Entity<T>
    | Pair<Entity<T>, Entity>
    | Pair<Entity, Entity<T>>
    | Pair<Entity<T>, Entity<unknown>>

export type Pair<P, O> = number & {
    __P: P,
    __O: O,
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

type Item<T...> = (self: Query<T...>) -> (Entity, T...)

export type Entity<T = nil> = number & { __T: T }

type Iter<T...> = (query: Query<T...>) -> () -> (Entity, T...)

export type Query<T...> = typeof(setmetatable({}, {
	__iter = (nil :: any) :: Iter<T...>,
})) & {
	iter: Iter<T...>,
	with: (self: Query<T...>, ...Id) -> Query<T...>,
	without: (self: Query<T...>, ...Id) -> Query<T...>,
	archetypes: (self: Query<T...>) -> { Archetype },
	cached: (self: Query<T...>) -> Query<T...>,
}

type Observer = {
 	callback: (archetype: Archetype) -> (),
   	query: QueryInner,
}

export type World = {
	archetypeIndex: { [string]: Archetype },
	archetypes: Archetypes,
	componentIndex: ComponentIndex,
	entity_index: EntityIndex,
	ROOT_ARCHETYPE: Archetype,

	nextComponentId: number,
	nextEntityId: number,
	nextArchetypeId: number,

	observerable: {
		[i53]: {
			[i53]: {
				{ query: QueryInner, callback: (Archetype) -> () }
			}
		}
	},
} & {
	--- Creates a new entity
	entity: (self: World) -> Entity,
	--- Creates a new entity located in the first 256 ids.
	--- These should be used for static components for fast access.
	component: <T>(self: World) -> Entity<T>,
	--- Gets the target of an relationship. For example, when a user calls
	--- `world:target(id, ChildOf(parent), 0)`, you will obtain the parent entity.
	target: (self: World, id: Entity, relation: Entity, index: number?) -> Entity?,
	--- Deletes an entity and all it's related components and relationships.
	delete: (self: World, id: Entity) -> (),

	--- Adds a component to the entity with no value
	add: <T>(self: World, id: Entity, component: Id<T>) -> (),
	--- Assigns a value to a component on the given entity
	set: <T>(self: World, id: Entity, component: Id<T>, data: T) -> (),

	cleanup: (self: World) -> (),
	-- Clears an entity from the world
	clear: (self: World, id: Entity) -> (),
	--- Removes a component from the given entity
	remove: (self: World, id: Entity, component: Id) -> (),
	--- Retrieves the value of up to 4 components. These values may be nil.
	get: (<A>(self: World, id: any, Id<A>) -> A?)
		& (<A, B>(self: World, id: Entity, Id<A>, Id<B>) -> (A?, B?))
		& (<A, B, C>(self: World, id: Entity, Id<A>, Id<B>, Id<C>) -> (A?, B?, C?))
		& <A, B, C, D>(self: World, id: Entity, Id<A>, Id<B>, Id<C>, Id<D>) -> (A?, B?, C?, D?),

	--- Returns whether the entity has the ID.
	has: (self: World, entity: Entity, ...Id) -> boolean,

	--- Get parent (target of ChildOf relationship) for entity. If there is no ChildOf relationship pair, it will return nil.
	parent: (self: World, entity: Entity) -> Entity,

	--- Checks if the world contains the given entity
	contains: (self: World, entity: Entity) -> boolean,

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

return {
	World = World :: { new: () -> World },

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

	pair = ECS_PAIR :: <P, O>(first: P, second: O) -> Pair<P, O>,

	-- Inwards facing API for testing
	ECS_ID = ECS_ENTITY_T_LO,
	ECS_GENERATION_INC = ECS_GENERATION_INC,
	ECS_GENERATION = ECS_GENERATION,
	ECS_ID_IS_WILDCARD = ECS_ID_IS_WILDCARD,

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
}
