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

type ArchetypeRecord = {
	count: number,
	column: number,
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
	dense_array: Map<i24, i53>,
	sparse_array: Map<i53, Record>,
	sparse_count: number,
	alive_count: number,
	max_id: number
}


local ECS_PAIR_FLAG =                      0x8
local ECS_ID_FLAGS_MASK =                 0x10
local ECS_ENTITY_MASK =     bit32.lshift(1, 24)
local ECS_GENERATION_MASK = bit32.lshift(1, 16)

-- HIGH 24 bits LOW 24 bits
local function ECS_GENERATION(e: i53): i24
	return if e > ECS_ENTITY_MASK then (e // ECS_ID_FLAGS_MASK) % ECS_GENERATION_MASK else 0
end

local function ECS_COMBINE(source: number, target: number): i53
	return (source * 268435456) + (target * ECS_ID_FLAGS_MASK)
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

		return ECS_COMBINE(id, next_gen) + flags
	end
	return ECS_COMBINE(e, 1)
end
local function ECS_ENTITY_T_LO(e: i53): i24
	return if e > ECS_ENTITY_MASK then (e // ECS_ID_FLAGS_MASK) // ECS_ENTITY_MASK else e
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

local function entity_index_get_alive(entity_index: EntityIndex,
	entity: number): number

	local r = entity_index_try_get_any(entity_index, entity)
	if r then
		return entity_index.dense_array[r.dense]
	end
	return 0
end

local function entity_index_remove(entity_index: EntityIndex, entity: number)
	local r = entity_index_try_get(entity_index, entity)
	if not r then
		return
	end
	local dense_array = entity_index.dense_array
	local index_of_deleted_entity = r.dense
	local last_entity_alive_at_index = entity_index.alive_count
	entity_index.alive_count -= 1

	local last_alive_entity = dense_array[last_entity_alive_at_index]
	local r_swap = entity_index_try_get_any(
		entity_index, last_alive_entity) :: Record
	r_swap.dense = index_of_deleted_entity
	r.archetype = nil :: any
	r.row = nil :: any
	r.dense = last_entity_alive_at_index

	dense_array[index_of_deleted_entity] = last_alive_entity
	dense_array[last_entity_alive_at_index] = ECS_GENERATION_INC(entity)
end

local function entity_index_new_id(entity_index: EntityIndex, data): i53
	local dense_array = entity_index.dense_array
	if entity_index.alive_count ~= #dense_array then
		entity_index.alive_count += 1
		local id = dense_array[entity_index.alive_count]
		return id
	end
	entity_index.max_id +=1
	local id = entity_index.max_id
	entity_index.alive_count += 1

	dense_array[entity_index.alive_count] = id
	entity_index.sparse_array[id] = {
		dense = entity_index.alive_count,
		archetype = data
	} :: Record

	entity_index.sparse_count += 1

	return id
end

local function entity_index_is_alive(entity_index: EntityIndex, entity: number)
	return entity_index_try_get(entity_index, entity) ~= nil
end

local eidx = {
	alive_count = 0,
	max_id = 0,
	sparse_array = {} :: { Record },
	sparse_count = 0,
	dense_array = {} :: { i53 }
}
local e1v0 = entity_index_new_id(eidx, "e1v0")
local e2v0 = entity_index_new_id(eidx, "e2v0")
local e3v0 = entity_index_new_id(eidx, "e3v0")
local e4v0 = entity_index_new_id(eidx, "e4v0")
local e5v0 = entity_index_new_id(eidx, "e5v0")
local t = require("@testkit")
local tprint = t.print
entity_index_remove(eidx, e5v0)
local e5v1 = entity_index_new_id(eidx, "e5v1")
entity_index_remove(eidx, e2v0)
tprint(eidx)
