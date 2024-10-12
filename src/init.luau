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
	prev: GraphEdge?,
	next: GraphEdge?,
	id: number,
}

type GraphEdges = Map<i53, GraphEdge>

type GraphNode = {
	add: GraphEdges,
	remove: GraphEdges,
	refs: GraphEdge,
}

export type Archetype = {
	id: number,
	node: GraphNode,
	types: Ty,
	type: string,
	entities: { number },
	columns: { Column },
	records: { ArchetypeRecord },
}
type Record = {
	archetype: Archetype,
	row: number,
	dense: i24,
}

type EntityIndex = {
	dense: Map<i24, i53>,
	sparse: Map<i53, Record>,
}

type ArchetypeRecord = {
	count: number,
	column: number,
}

type IdRecord = {
	cache: { ArchetypeRecord },
	flags: number,
	size: number,
}

type ComponentIndex = Map<i53, IdRecord>

type Archetypes = { [ArchetypeId]: Archetype }

type ArchetypeDiff = {
	added: Ty,
	removed: Ty,
}

local HI_COMPONENT_ID = _G.__JECS_HI_COMPONENT_ID or 256

local EcsOnAdd = HI_COMPONENT_ID + 1
local EcsOnRemove = HI_COMPONENT_ID + 2
local EcsOnSet = HI_COMPONENT_ID + 3
local EcsWildcard = HI_COMPONENT_ID + 4
local EcsChildOf = HI_COMPONENT_ID + 5
local EcsComponent = HI_COMPONENT_ID + 6
local EcsOnDelete = HI_COMPONENT_ID + 7
local EcsOnDeleteTarget = HI_COMPONENT_ID + 8
local EcsDelete = HI_COMPONENT_ID + 9
local EcsRemove = HI_COMPONENT_ID + 10
local EcsName = HI_COMPONENT_ID + 11
local EcsRest = HI_COMPONENT_ID + 12

local ECS_PAIR_FLAG = 0x8
local ECS_ID_FLAGS_MASK = 0x10
local ECS_ENTITY_MASK = bit32.lshift(1, 24)
local ECS_GENERATION_MASK = bit32.lshift(1, 16)

local ECS_ID_DELETE = 0b0000_0001
local ECS_ID_IS_TAG = 0b0000_0010
local ECS_ID_HAS_ON_ADD = 0b0000_0100
local ECS_ID_HAS_ON_SET = 0b0000_1000
local ECS_ID_HAS_ON_REMOVE = 0b0001_0000
local ECS_ID_MASK = 0b0000_0000

local NULL_ARRAY = table.freeze({})

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

		return ECS_COMBINE(id, generation + 1) + flags
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
	return ECS_COMBINE(ECS_ENTITY_T_LO(obj), ECS_ENTITY_T_LO(pred)) + FLAGS_ADD(--[[isPair]] true) :: i53
end

local ERROR_ENTITY_NOT_ALIVE = "Entity is not alive"
local ERROR_GENERATION_INVALID = "INVALID GENERATION"

local function entity_index_get_alive(index: EntityIndex, e: i24): i53
	local denseArray = index.dense
	local id = denseArray[ECS_ENTITY_T_LO(e)]

	if id then
		local currentGeneration = ECS_GENERATION(id)
		local gen = ECS_GENERATION(e)
		if gen == currentGeneration then
			return id
		end

		error(ERROR_GENERATION_INVALID)
	end

	error(ERROR_ENTITY_NOT_ALIVE)
end

local function _entity_index_sparse_get(entityIndex, id)
	return entityIndex.sparse[entity_index_get_alive(entityIndex, id)]
end

-- ECS_PAIR_FIRST, gets the relationship target / obj / HIGH bits
local function ecs_pair_first(world, e)
	return entity_index_get_alive(world.entityIndex, ECS_ENTITY_T_HI(e))
end

-- ECS_PAIR_SECOND gets the relationship / pred / LOW bits
local function ecs_pair_second(world, e)
	return entity_index_get_alive(world.entityIndex, ECS_ENTITY_T_LO(e))
end

local function entity_index_new_id(entityIndex: EntityIndex, index: i24): i53
	--local id = ECS_COMBINE(index, 0)
	local id = index
	entityIndex.sparse[id] = {
		dense = index,
	} :: Record
	entityIndex.dense[index] = id

	return id
end

local function archetype_move(entity_index: EntityIndex, to: Archetype, dst_row: i24, from: Archetype, src_row: i24)
	local src_columns = from.columns
	local dst_columns = to.columns
	local dst_entities = to.entities
	local src_entities = from.entities

	local last = #src_entities
	local types = from.types
	local records = to.records

	for i, column in src_columns do
		if column == NULL_ARRAY then
			continue
		end
		-- Retrieves the new column index from the source archetype's record from each component
		-- We have to do this because the columns are tightly packed and indexes may not correspond to each other.
		local tr = records[types[i]]

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

	local sparse = entity_index.sparse
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

	local record1 = sparse[e1]
	local record2 = sparse[e2]

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

local world_get: (world: World, entityId: i53, a: i53, b: i53?, c: i53?, d: i53?, e: i53?) -> ...any
do
	-- Keeping the function as small as possible to enable inlining
	local records
	local columns
	local row

	local function fetch(id)
		local tr = records[id]

		if not tr then
			return nil
		end

		return columns[tr.column][row]
	end

	function world_get(world: World, entity: i53, a: i53, b: i53?, c: i53?, d: i53?, e: i53?): ...any
		local record = world.entityIndex.sparse[entity]
		if not record then
			return nil
		end

		local archetype = record.archetype
		if not archetype then
			return nil
		end

		records = archetype.records
		columns = archetype.columns
		row = record.row

		local va = fetch(a)

		if not b then
			return va
		elseif not c then
			return va, fetch(b)
		elseif not d then
			return va, fetch(b), fetch(c)
		elseif not e then
			return va, fetch(b), fetch(c), fetch(d)
		else
			error("args exceeded")
		end
	end
end

local function world_get_one_inline(world: World, entity: i53, id: i53)
	local record = world.entityIndex.sparse[entity]
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
	local record = world.entityIndex.sparse[entity]
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
	local record = world.entityIndex.sparse[entity]
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

local function world_target(world: World, entity: i53, relation: i24, index): i24?
	if index == nil then
		index = 0
	end
	local record = world.entityIndex.sparse[entity]
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
	if index >= count then
		index = index + count + 1
	end

	local nth = archetype.types[index + tr.column]

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
	local idr = componentIndex[id]

	if not idr then
		local flags = ECS_ID_MASK
		local relation = ECS_ENTITY_T_HI(id)

		local cleanup_policy = world_target(world, relation, EcsOnDelete, 0)
		local cleanup_policy_target = world_target(world, relation, EcsOnDeleteTarget, 0)

		local has_delete = false

		if cleanup_policy == EcsDelete or cleanup_policy_target == EcsDelete then
			has_delete = true
		end

		local on_add, on_set, on_remove = world_get(world, relation, EcsOnAdd, EcsOnSet, EcsOnRemove)

		local is_tag = not world_has_one_inline(world, relation, EcsComponent)

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
		} :: IdRecord
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

local function archetype_create(world: World, types: { i24 }, ty, prev: i53?): Archetype
	local archetype_id = (world.nextArchetypeId :: number) + 1
	world.nextArchetypeId = archetype_id

	local length = #types
	local columns = (table.create(length) :: any) :: { Column }

	local records: { ArchetypeRecord } = {}
	for i, componentId in types do
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

	local archetype: Archetype = {
		columns = columns,
		node = { add = {}, remove = {}, refs = {} :: GraphEdge },
		entities = {},
		id = archetype_id,
		records = records,
		type = ty,
		types = types,
	}

	world.archetypeIndex[ty] = archetype
	world.archetypes[archetype_id] = archetype

	return archetype
end

local function world_entity(world: World): i53
	local entityId = (world.nextEntityId :: number) + 1
	world.nextEntityId = entityId
	return entity_index_new_id(world.entityIndex, entityId + EcsRest)
end

local function world_parent(world: World, entity: i53)
	return world_target(world, entity, EcsChildOf, 0)
end

local function archetype_ensure(world: World, types): Archetype
	if #types < 1 then
		return world.ROOT_ARCHETYPE
	end

	local ty = hash(types)
	local archetype = world.archetypeIndex[ty]
	if archetype then
		return archetype
	end

	return archetype_create(world, types, ty)
end

local function find_insert(types: { i53 }, toAdd: i53): number
	for i, id in types do
		if id == toAdd then
			return -1
		end
		if id > toAdd then
			return i
		end
	end
	return #types + 1
end

local function find_archetype_with(world: World, node: Archetype, id: i53): Archetype
	local types = node.types
	-- Component IDs are added incrementally, so inserting and sorting
	-- them each time would be expensive. Instead this insertion sort can find the insertion
	-- point in the types array.

	local dst = table.clone(node.types) :: { i53 }
	local at = find_insert(types, id)
	if at == -1 then
		-- If it finds a duplicate, it just means it is the same archetype so it can return it
		-- directly instead of needing to hash types for a lookup to the archetype.
		return node
	end
	table.insert(dst, at, id)

	return archetype_ensure(world, dst)
end

local function find_archetype_without(world: World, node: Archetype, id: i53): Archetype
	local types = node.types
	local at = table.find(types, id)
	if at == nil then
		return node
	end

	local dst = table.clone(types)
	table.remove(dst, at)

	return archetype_ensure(world, dst)
end

local function archetype_init_edge(archetype: Archetype, edge: GraphEdge, id: i53, to: Archetype)
	edge.from = archetype
	edge.to = to
	edge.id = id
end

local function archetype_ensure_edge(world, edges, id): GraphEdge
	local edge = edges[id]
	if not edge then
		edge = {} :: GraphEdge
		edges[id] = edge
	end

	return edge
end

local function init_edge_for_add(world, archetype, edge: GraphEdge, id, to)
	archetype_init_edge(archetype, edge, id, to)
	archetype_ensure_edge(world, archetype.node.add, id)
	if archetype ~= to then
		local to_refs = to.node.refs
		local next_edge = to_refs.next

		to_refs.next = edge
		edge.prev = to_refs
		edge.next = next_edge

		if next_edge then
			next_edge.prev = edge
		end
	end
end

local function init_edge_for_remove(world, archetype, edge, id, to)
	archetype_init_edge(archetype, edge, id, to)
	archetype_ensure_edge(world, archetype.node.remove, id)
	if archetype ~= to then
		local to_refs = to.node.refs
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
	local edge = archetype_ensure_edge(world, from.node.add, id)

	local to = edge.to
	if not to then
		to = create_edge_for_add(world, from, edge, id)
	end

	return to :: Archetype
end

local function archetype_traverse_remove(world: World, id: i53, from: Archetype): Archetype
	from = from or world.ROOT_ARCHETYPE

	local edge = archetype_ensure_edge(world, from.node.remove, id)

	local to = edge.to
	if not to then
		to = create_edge_for_remove(world, from, edge, id)
	end

	return to :: Archetype
end

local function invoke_hook(world: World, hook_id: number, id: i53, entity: i53, data: any?)
	local hook = world_get_one_inline(world, id, hook_id)
	if hook then
		hook(entity, data)
	end
end

local function world_add(world: World, entity: i53, id: i53): ()
	local entityIndex = world.entityIndex
	local record = entityIndex.sparse[entity]
	local from = record.archetype
	local to = archetype_traverse_add(world, id, from)
	if from == to then
		return
	end
	if from then
		entity_move(entityIndex, entity, record, to)
	else
		if #to.types > 0 then
			new_entity(entity, record, to)
		end
	end

	local idr = world.componentIndex[id]
	local has_on_add = bit32.band(idr.flags, ECS_ID_HAS_ON_ADD) ~= 0

	if has_on_add then
		invoke_hook(world, EcsOnAdd, id, entity)
	end
end

local function world_set(world: World, entity: i53, id: i53, data: unknown): ()
	local entityIndex = world.entityIndex
	local record = entityIndex.sparse[entity]
	local from = record.archetype
	local to = archetype_traverse_add(world, id, from)
	local idr = world.componentIndex[id]
	local flags = idr.flags
	local is_tag = bit32.band(flags, ECS_ID_IS_TAG) ~= 0
	local has_on_set = bit32.band(flags, ECS_ID_HAS_ON_SET) ~= 0

	if from == to then
		if is_tag then
			return
		end
		-- If the archetypes are the same it can avoid moving the entity
		-- and just set the data directly.
		local tr = to.records[id]
		from.columns[tr.column][record.row] = data
		if has_on_set then
			invoke_hook(world, EcsOnSet, id, entity, data)
		end

		return
	end

	if from then
		-- If there was a previous archetype, then the entity needs to move the archetype
		entity_move(entityIndex, entity, record, to)
	else
		if #to.types > 0 then
			-- When there is no previous archetype it should create the archetype
			new_entity(entity, record, to)
		end
	end

	local has_on_add = bit32.band(flags, ECS_ID_HAS_ON_ADD) ~= 0

	if has_on_add then
		invoke_hook(world, EcsOnAdd, id, entity)
	end

	if is_tag then
		return
	end

	local tr = to.records[id]
	local column = to.columns[tr.column]

	column[record.row] = data

	if has_on_set then
		invoke_hook(world, EcsOnSet, id, entity, data)
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
	local id = entity_index_new_id(world.entityIndex, componentId)
	world_add(world, id, EcsComponent)
	return id
end

local function world_remove(world: World, entity: i53, id: i53)
	local entity_index = world.entityIndex
	local record = entity_index.sparse[entity]
	local from = record.archetype
	if not from then
		return
	end
	local to = archetype_traverse_remove(world, id, from)

	if from and not (from == to) then
		local idr = world.componentIndex[id]
		local flags = idr.flags
		local has_on_remove = bit32.band(flags, ECS_ID_HAS_ON_REMOVE) ~= 0
		if has_on_remove then
			invoke_hook(world, EcsOnRemove, id, entity)
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
	local entityIndex = world.entityIndex
	local columns = archetype.columns
	local types = archetype.types
	local entities = archetype.entities
	local column_count = #entities
	local last = #entities
	local move = entities[last]
	local delete = entities[row]
	entities[row] = move
	entities[last] = nil

	if row ~= last then
		-- TODO: should be "entity_index_sparse_get(entityIndex, move)"
		local record_to_move = entityIndex.sparse[move]
		if record_to_move then
			record_to_move.row = row
		end
	end

	-- TODO: if last == 0 then deactivate table

	for _, id in types do
		invoke_hook(world, EcsOnRemove, id, delete)
	end

	if row == last then
		archetype_fast_delete_last(columns, column_count, types, delete)
	else
		archetype_fast_delete(columns, column_count, row, types, delete)
	end
end

local function world_clear(world: World, entity: i53)
	--TODO: use sparse_get (stashed)
	local record = world.entityIndex.sparse[entity]
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

	record.archetype = nil
	record.row = nil
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
	edges[id] = nil
end

local function archetype_clear_edges(archetype: Archetype)
	local node = archetype.node
	local add = node.add
	local remove = node.remove
	local node_refs = node.refs
	for id, edge in add do
		archetype_disconnect_edge(edge)
		add[id] = nil
	end
	for id, edge in remove do
		archetype_disconnect_edge(edge)
		remove[id] = nil
	end

	local cur = node_refs.next
	while cur do
		local edge = cur
		local next_edge = edge.next
		archetype_remove_edge(edge.from.node.add, edge.id, edge)
		cur = next_edge
	end

	cur = node_refs.prev
	while cur do
		local edge = cur
		local next_edge = edge.prev
		archetype_remove_edge(edge.from.node.remove, edge.id, edge)
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
	world.archetypes[archetype_id] = nil
	world.archetypeIndex[archetype.type] = nil
	local records = archetype.records

	for id in records do
		local idr = component_index[id]
		idr.cache[archetype_id] = nil
		idr.size -= 1
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

	local new_archetypes = table.create(#archetypes)
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
		local entityIndex = world.entityIndex
		local sparse_array = entityIndex.sparse

		local record = sparse_array[entity]
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
		local archetypes = world.archetypes
		local tgt = ECS_PAIR(EcsWildcard, delete)
		local idr_t = component_index[tgt]
		local idr = component_index[delete]

		if idr then
			local children = {}
			for archetype_id in idr.cache do
				local idr_archetype = archetypes[archetype_id]

				for i, child in idr_archetype.entities do
					table.insert(children, child)
				end
			end
			local flags = idr.flags
			if bit32.band(flags, ECS_ID_DELETE) ~= 0 then
				for _, child in children do
					-- Cascade deletion to children
					world_delete(world, child)
				end
			else
				for _, child in children do
					world_remove(world, child, delete)
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
					local object = ECS_ENTITY_T_LO(id)
					if object == delete then
						local id_record = component_index[id]
						local flags = id_record.flags
						if bit32.band(flags, ECS_ID_DELETE) ~= 0 then
							for _, child in children do
								-- Cascade deletions of it has Delete as component trait
								world_delete(world, child, destruct)
							end

							break
						else
							for _, child in children do
								world_remove(world, child, id)
							end
						end
					end
				end

				archetype_destroy(world, idr_t_archetype)
			end
		end

		record.archetype = nil :: any
		sparse_array[entity] = nil
	end
end

local function world_contains(world: World, entity): boolean
	return world.entityIndex.sparse[entity] ~= nil
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

local function query_iter_init(query)
	local world_query_iter_next

	local compatible_archetypes = query.compatible_archetypes
	local lastArchetype = 1
	local archetype = compatible_archetypes[1]
	if not archetype then
		return EMPTY_QUERY
	end
	local columns = archetype.columns
	local entities = archetype.entities
	local i = #entities
	local records = archetype.records

	local ids = query.ids
	local A, B, C, D, E, F, G, H, I = unpack(ids)
	local a, b, c, d, e, f, g, h

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
				entityId = entities[i]
				columns = archetype.columns
				local records = archetype.records
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
				entityId = entities[i]
				columns = archetype.columns
				local records = archetype.records
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
				entityId = entities[i]
				columns = archetype.columns
				local records = archetype.records
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
				entityId = entities[i]
				columns = archetype.columns
				local records = archetype.records
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
				entityId = entities[i]
				columns = archetype.columns
				local records = archetype.records

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

			local records = archetype.records
			for j, id in ids do
				queryOutput[j] = columns[records[id].column][row]
			end

			return entityId, unpack(queryOutput)
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
	local compatible_archetypes = query.compatible_archetypes
	local N = select("#", ...)
	for i = #compatible_archetypes, 1, -1 do
		local archetype = compatible_archetypes[i]
		local records = archetype.records
		local shouldRemove = false

		for j = 1, N do
			local id = select(j, ...)
			if records[id] then
				shouldRemove = true
				break
			end
		end

		if shouldRemove then
			local last = #compatible_archetypes
			if last ~= i then
				compatible_archetypes[i] = compatible_archetypes[last]
			end
			compatible_archetypes[last] = nil
		end
	end

	if #compatible_archetypes == 0 then
		return EMPTY_QUERY
	end

	return query
end

local function query_with(query, ...)
	local compatible_archetypes = query.compatible_archetypes
	local N = select("#", ...)
	for i = #compatible_archetypes, 1, -1 do
		local archetype = compatible_archetypes[i]
		local records = archetype.records
		local shouldRemove = false

		for j = 1, N do
			local id = select(j, ...)
			if not records[id] then
				shouldRemove = true
				break
			end
		end

		if shouldRemove then
			local last = #compatible_archetypes
			if last ~= i then
				compatible_archetypes[i] = compatible_archetypes[last]
			end
			compatible_archetypes[last] = nil
		end
	end
	if #compatible_archetypes == 0 then
		return EMPTY_QUERY
	end
	return query
end

-- Meant for directly iterating over archetypes to minimize
-- function call overhead. Should not be used unless iterating over
-- hundreds of thousands of entities in bulk.
local function query_archetypes(query)
	return query.compatible_archetypes
end

local Query = {}
Query.__index = Query
Query.__iter = query_iter
Query.iter = query_iter_init
Query.without = query_without
Query.with = query_with
Query.archetypes = query_archetypes

local function world_query(world: World, ...)
	local compatible_archetypes = {}
	local length = 0

	local ids = { ... }

	local archetypes = world.archetypes

	local idr: IdRecord
	local componentIndex = world.componentIndex

	for _, id in ids do
		local map = componentIndex[id]
		if not map then
			return EMPTY_QUERY
		end

		if idr == nil or map.size < idr.size then
			idr = map
		end
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

	if length == 0 then
		return EMPTY_QUERY
	end

	local q = setmetatable({
		compatible_archetypes = compatible_archetypes,
		ids = ids,
	}, Query) :: any

	return q
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

if _G.__JECS_DEBUG then
	-- taken from https://github.com/centau/ecr/blob/main/src/ecr.luau
	-- error but stack trace always starts at first callsite outside of this file
	local function throw(msg: string)
		local s = 1
		repeat
			s += 1
		until debug.info(s, "s") ~= debug.info(1, "s")
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

	local function get_name(world, id): string
		local name: string | nil
		if ECS_IS_PAIR(id) then
			name = `pair({get_name(world, ECS_ENTITY_T_HI(id))}, {get_name(world, ECS_ENTITY_T_LO(id))})`
		else
			local _1 = world_get_one_inline(world, id, EcsName)
			if _1 then
				name = `${_1}`
			end
		end
		if name then
			return name
		else
			return `${id}`
		end
	end

	local function ID_IS_TAG(world, id)
		return not world_has_one_inline(world, ECS_ENTITY_T_HI(id), EcsComponent)
	end

	local original_invoke_hook = invoke_hook
	local invoked_hook = false
	invoke_hook = function(...)
		invoked_hook = true
		original_invoke_hook(...)
		invoked_hook = false
	end

	World.query = function(world: World, ...)
		ASSERT((...), "Requires at least a single component")
		return world_query(world, ...)
	end

	World.set = function(world: World, entity: i53, id: i53, value: any): ()
		local is_tag = ID_IS_TAG(world, id)
		if is_tag and value == nil then
			world_add(world, entity, id)
			local _1 = get_name(world, entity)
			local _2 = get_name(world, id)
			local why = "cannot set component value to nil"
			throw(why)
			return
		elseif value ~= nil and is_tag then
			world_add(world, entity, id)
			local _1 = get_name(world, entity)
			local _2 = get_name(world, id)
			local why = `cannot set a component value because {_2} is a tag`
			why ..= `\n[jecs] note: consider using "world:add({_1}, {_2})" instead`
			throw(why)
			return
		end

		if world_has_one_inline(world, entity, id) then
			if invoked_hook then
				local file, line = debug.info(2, "sl")
				local hook_fn = `{file}::{line}`
				local why = `cannot call world:set inside {hook_fn} because it adds the component {get_name(world, id)}`
				why ..= `\n[jecs note]: consider handling this logic inside of a system`
				throw(why)
				return
			end
		end

		world_set(world, entity, id, value)
	end

	World.add = function(world: World, entity: i53, id: i53, value: nil)
		if value ~= nil then
			local _1 = get_name(world, entity)
			local _2 = get_name(world, id)
			throw("You provided a value when none was expected. " .. `Did you mean to use "world:add({_1}, {_2})"`)
			return
		end

		if invoked_hook then
			local hook_fn = debug.info(2, "sl")
			throw(`Cannot call world:add when the hook {hook_fn} is in process`)
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
	local self = setmetatable({
		archetypeIndex = {} :: { [string]: Archetype },
		archetypes = {} :: Archetypes,
		componentIndex = {} :: ComponentIndex,
		entityIndex = {
			dense = {} :: { [i24]: i53 },
			sparse = {} :: { [i53]: Record },
		} :: EntityIndex,
		nextArchetypeId = 0 :: number,
		nextComponentId = 0 :: number,
		nextEntityId = 0 :: number,
		ROOT_ARCHETYPE = (nil :: any) :: Archetype,
	}, World) :: any

	self.ROOT_ARCHETYPE = archetype_create(self, {}, "")

	for i = HI_COMPONENT_ID + 1, EcsRest do
		-- Initialize built-in components
		entity_index_new_id(self.entityIndex, i)
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

export type Id<T = nil> = Entity<T> | Pair

export type Pair = number

type Item<T...> = (self: Query<T...>) -> (Entity, T...)

export type Entity<T = nil> = number & { __T: T }

type Iter<T...> = (query: Query<T...>) -> () -> (Entity, T...)

type Query<T...> = typeof(setmetatable({}, {
	__iter = (nil :: any) :: Iter<T...>,
})) & {
	iter: Iter<T...>,
	with: (self: Query<T...>, ...i53) -> Query<T...>,
	without: (self: Query<T...>, ...i53) -> Query<T...>,
	archetypes: (self: Query<T...>) -> { Archetype },
}

export type World = {
	archetypeIndex: { [string]: Archetype },
	archetypes: Archetypes,
	componentIndex: ComponentIndex,
	entityIndex: EntityIndex,
	ROOT_ARCHETYPE: Archetype,

	nextComponentId: number,
	nextEntityId: number,
	nextArchetypeId: number,
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

	--- Searches the world for entities that match a given query
	query: (<A>(self: World, Id<A>) -> Query<A>)
		& (<A, B>(self: World, Id<A>, Id<B>) -> Query<A, B>)
		& (<A, B, C>(self: World, Id<A>, Id<B>, Id<C>) -> Query<A, B, C>)
		& (<A, B, C, D>(self: World, Id<A>, Id<B>, Id<C>, Id<D>) -> Query<A, B, C, D>)
		& (<A, B, C, D, E>(self: World, Id<A>, Id<B>, Id<C>, Id<D>, Id<E>) -> Query<A, B, C, D, E>)
		& (<A, B, C, D, E, F>(
			self: World,
			Id<A>,
			Id<B>,
			Id<C>,
			Id<D>,
			Id<E>,
			Id<F>
		) -> Query<A, B, C, D, E, F>)
		& (<A, B, C, D, E, F, G>(
			self: World,
			Id<A>,
			Id<B>,
			Id<C>,
			Id<D>,
			Id<E>,
			Id<F>,
			Id<G>
		) -> Query<A, B, C, D, E, F, G>)
		& (<A, B, C, D, E, F, G, H>(
			self: World,
			Id<A>,
			Id<B>,
			Id<C>,
			Id<D>,
			Id<E>,
			Id<F>,
			Id<G>,
			Id<H>,
			...Id<any>
		) -> Query<A, B, C, D, E, F, G, H>),
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

	pair = ECS_PAIR,

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
}
