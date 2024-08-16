--!optimize 2
--!native
--!strict
--draft 4

type i53 = number
type i24 = number

type Ty = { i53 }
type ArchetypeId = number

type Column = { any }

type ArchetypeEdge = {
	add: Archetype,
	remove: Archetype,
}

export type Archetype = {
	id: number,
	edges: { [i53]: ArchetypeEdge },
	types: Ty,
	type: string | number,
	entities: { number },
	columns: { Column },
	records: { ArchetypeRecord },
}
type Record = {
	archetype: Archetype,
	row: number,
	dense: i24,
	componentRecord: ArchetypeMap,
}

type EntityIndex = { dense: { [i24]: i53 }, sparse: { [i53]: Record } }

type ArchetypeRecord = {
	count: number,
	column: number,
}

type ArchetypeMap = {
	cache: { ArchetypeRecord },
	flags: number,
	first: ArchetypeMap,
	second: ArchetypeMap,
	parent: ArchetypeMap,
	size: number,
}

type ComponentIndex = { [i24]: ArchetypeMap }

type Archetypes = { [ArchetypeId]: Archetype }

type ArchetypeDiff = {
	added: Ty,
	removed: Ty,
}

local HI_COMPONENT_ID 		= 256

local EcsOnAdd 				= HI_COMPONENT_ID + 1
local EcsOnRemove 			= HI_COMPONENT_ID + 2
local EcsOnSet 				= HI_COMPONENT_ID + 3
local EcsWildcard 			= HI_COMPONENT_ID + 4
local EcsChildOf 			= HI_COMPONENT_ID + 5
local EcsComponent  		= HI_COMPONENT_ID + 6
local EcsOnDeleteTarget     = HI_COMPONENT_ID + 7
local EcsDelete             = HI_COMPONENT_ID + 8
local EcsRest 				= HI_COMPONENT_ID + 9

local ECS_PAIR_FLAG 		= 0x8
local ECS_ID_FLAGS_MASK 	= 0x10
local ECS_ENTITY_MASK 		= bit32.lshift(1, 24)
local ECS_GENERATION_MASK 	= bit32.lshift(1, 16)

local ECS_ID_HAS_DELETE     = 0b0001
local ECS_ID_HAS_HOOKS      = 0b0010
--local EcsIdExclusive   = 0b0100

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

local function STRIP_GENERATION(e: i53): i24
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

local function entity_index_sparse_get(entityIndex, id)
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

local function archetype_move(entity_index: EntityIndex, to: Archetype,
	dst_row: i24, from: Archetype, src_row: i24)

	local src_columns = from.columns
	local dst_columns = to.columns
	local dst_entities = to.entities
	local src_entities = from.entities

	local last = #src_entities
	local types = from.types
	local records = to.records

	for i, column in src_columns do
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

local world_get: (world: World, entityId: i53, a: i53, b: i53?, c: i53?, d: i53?, e: i53?) -> (...any)
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

local function world_has_any(world: World, entity: number, ...: i53): boolean
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
        if records[select(i, ...)] then
            return true
        end
    end

    return false
end

-- TODO:
-- should have an additional `nth` parameter which selects the nth target
-- this is important when an entity can have multiple relationships with the same target
local function world_target(world: World, entity: i53, relation: i24--[[, nth: number]]): i24?
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

	return ecs_pair_second(world, archetype.types[tr.column])
end

local function id_record_ensure(
    world: World,
	id: number
): ArchetypeMap
    local componentIndex = world.componentIndex
	local idr = componentIndex[id]

	if not idr then
	    local flags = 0b0000
		local relation = ECS_ENTITY_T_HI(id)
		local cleanup_policy = world_target(world, relation, EcsOnDeleteTarget)
		if cleanup_policy == EcsDelete then
            flags = bit32.bor(flags, ECS_ID_HAS_DELETE)
		end

		if world_has_any(world, relation,
		    EcsOnAdd, EcsOnSet, EcsOnRemove)
		then
		    flags = bit32.bor(flags, ECS_ID_HAS_HOOKS)
		end

		-- local FLAG2 = 0b0010
		-- local FLAG3 = 0b0100
		-- local FLAG4 = 0b1000

		idr = {
		    size = 0,
			cache = {},
			flags = flags
		} :: ArchetypeMap
		componentIndex[id] = idr
	end

	return idr
end

local function ECS_ID_IS_WILDCARD(e: i53): boolean
	assert(ECS_IS_PAIR(e))
	local first = ECS_ENTITY_T_HI(e)
	local second = ECS_ENTITY_T_LO(e)
	return first == EcsWildcard or second == EcsWildcard
end

local function archetype_create(world: World, types: { i24 }, prev: Archetype?): Archetype
	local ty = hash(types)

	local id = (world.nextArchetypeId :: number) + 1
	world.nextArchetypeId = id

	local length = #types
	local columns = (table.create(length) :: any) :: { Column }

	local records: { ArchetypeRecord } = {}
	for i, componentId in types do
	    local tr = { column = i, count = 1 }
		local idr = id_record_ensure(world, componentId)
		idr.cache[id] = tr
		idr.size += 1
		records[componentId] = tr
		if ECS_IS_PAIR(componentId) then
			local relation = ecs_pair_first(world, componentId)
			local object = ecs_pair_second(world, componentId)

			local r = ECS_PAIR(relation, EcsWildcard)
			local idr_r = id_record_ensure(world, r)

			local o = ECS_PAIR(EcsWildcard, object)
			local idr_o = id_record_ensure(world, o)

			records[r] = tr
			records[o] = tr

			idr_r.cache[id] = tr
			idr_o.cache[id] = tr

			idr_r.size += 1
			idr_o.size += 1
		end
		columns[i] = {}
	end

	local archetype: Archetype = {
		columns = columns,
		edges = {},
		entities = {},
		id = id,
		records = records,
		type = ty,
		types = types,
	}

	world.archetypeIndex[ty] = archetype
	world.archetypes[id] = archetype

	return archetype
end

local function world_entity(world: World): i53
	local entityId = (world.nextEntityId :: number) + 1
	world.nextEntityId = entityId
	return entity_index_new_id(world.entityIndex, entityId + EcsRest)
end

local function world_parent(world: World, entity: i53)
	return world_target(world, entity, EcsChildOf)
end

local function archetype_ensure(world: World, types, prev): Archetype
	if #types < 1 then
		return world.ROOT_ARCHETYPE
	end

	local ty = hash(types)
	local archetype = world.archetypeIndex[ty]
	if archetype then
		return archetype
	end

	return archetype_create(world, types, prev)
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

	return archetype_ensure(world, dst, node)
end

local function edge_ensure(archetype: Archetype, id: i53): ArchetypeEdge
	local edges = archetype.edges
	local edge = edges[id]
	if not edge then
		edge = {} :: any
		edges[id] = edge
	end
	return edge
end

local function archetype_traverse_add(world: World, id: i53, from: Archetype): Archetype
	from = from or world.ROOT_ARCHETYPE

	local edge = edge_ensure(from, id)
	local add = edge.add
	if not add then
		-- Save an edge using the component ID to the archetype to allow
		-- faster traversals to adjacent archetypes.
		add = find_archetype_with(world, from, id)
		edge.add = add :: never
	end

	return add
end

local function invoke_hook(world: World, hook_id: number, id: i53, entity: i53, data: any?)
    local hook = world_get_one_inline(world, id, hook_id)
    if hook then
        hook(entity, data)
    end
end

local function world_add(world: World, entity: i53, id: i53)
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
	local has_hooks = bit32.band(idr.flags, ECS_ID_HAS_HOOKS) ~= 0

	if has_hooks then
	    invoke_hook(world, EcsOnAdd, id, entity)
	end
end

-- Symmetric like `World.add` but idempotent
local function world_set(world: World, entity: i53, id: i53, data: unknown)
    local entityIndex = world.entityIndex
	local record = entityIndex.sparse[entity]
	local from = record.archetype
	local to = archetype_traverse_add(world, id, from)
	local idr = world.componentIndex[id]
	local has_hooks = bit32.band(idr.flags, ECS_ID_HAS_HOOKS) ~= 0

    if from == to then
		-- If the archetypes are the same it can avoid moving the entity
		-- and just set the data directly.
		local tr = to.records[id]
		from.columns[tr.column][record.row] = data
		if has_hooks then
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

    local tr = to.records[id]
	local column = to.columns[tr.column]

    if not has_hooks then
        column[record.row] = data
	else
    	invoke_hook(world, EcsOnAdd, id, entity, data)
	    column[record.row] = data
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

local function archetype_traverse_remove(world: World, id: i53, from: Archetype): Archetype
	local edge = edge_ensure(from, id)

	local remove = edge.remove
	if not remove then
		local to = table.clone(from.types) :: { i53 }
		local at = table.find(to, id)
		if not at then
			return from
		end
		table.remove(to, at)
		remove = archetype_ensure(world, to, from)
		edge.remove = remove :: any
	end

	return remove
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
	    invoke_hook(world, EcsOnRemove, id, entity)
		entity_move(entity_index, entity, record, to)
	end
end

local function world_clear(world: World, entity: i53)
	--TODO: use sparse_get (stashed)
	local record = world.entityIndex.sparse[entity]
	if not record then
		return
	end

	local ROOT_ARCHETYPE = world.ROOT_ARCHETYPE
	local archetype = record.archetype

	if archetype == nil or archetype == ROOT_ARCHETYPE then
		return
	end

	entity_move(world.entityIndex, entity, record, ROOT_ARCHETYPE)
end

local function archetype_fast_delete_last(columns, column_count,
    types, entity)

    for i, column in columns do
        column[column_count] = nil
    end
end

local function archetype_fast_delete(columns, column_count,
    row, types, entity)

    for i, column in columns do
        column[row] = column[column_count]
        column[column_count] = nil
    end
end

local ERROR_DELETE_PANIC = "Tried to delete entity that has (OnDelete, Panic)"

local function archetype_delete(world: World,
    archetype: Archetype, row: number)

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
        archetype_fast_delete_last(columns,
            column_count, types, delete)
    else
        archetype_fast_delete(columns, column_count,
            row, types, delete)
    end


	local component_index = world.componentIndex
	local archetypes = world.archetypes

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
        if bit32.band(flags, ECS_ID_HAS_DELETE) ~= 0 then
            for _, child in children do
                -- Cascade deletion to children
                world_delete(world, child)
            end
        else
            for _, child in children do
                world_remove(world, child, delete)
            end
        end

        component_index[delete] = nil
    end

    -- TODO: iterate each linked record.
    -- local r = ECS_PAIR(delete, EcsWildcard)
    -- local idr_r = component_index[r]
    -- if idr_r then
    --     -- Doesn't work for relations atm
    --     for archetype_id in idr_o.cache do
    --         local children = {}
    --         local idr_r_archetype = archetypes[archetype_id]
    --         local idr_r_types = idr_r_archetype.types

    --         for _, child in idr_r_archetype.entities do
    --             table.insert(children, child)
    --         end

    --         for _, id in idr_r_types do
    --             local relation = ECS_ENTITY_T_HI(id)
    --             if world_target(world, child, relation) == delete then
    --                 world_remove(world, child, ECS_PAIR(relation, delete))
    --             end
    --         end
    --     end
    -- end

    local o = ECS_PAIR(EcsWildcard, delete)
    local idr_o = component_index[o]

    if idr_o then
        for archetype_id in idr_o.cache do
            local children = {}
            local idr_o_archetype = archetypes[archetype_id]
            -- In the future, this needs to be optimized to only
            -- look for linked records instead of doing this linearly

            local idr_o_types = idr_o_archetype.types

            for _, child in idr_o_archetype.entities do
                table.insert(children, child)
            end

            for _, id in idr_o_types do
                if not ECS_IS_PAIR(id) then
                    continue
                end

                local id_record = component_index[id]

                if id_record then
                    local flags = id_record.flags
                    if bit32.band(flags, ECS_ID_HAS_DELETE) ~= 0 then
                        for _, child in children do
                            -- Cascade deletions of it has Delete as component trait
                            world_delete(world, child)
                        end
                    else
                        local object = ECS_ENTITY_T_LO(id)
                        if object == delete then
                            for _, child in children do
                                world_remove(world, child, id)
                            end
                        end
                    end
                end
            end
        end
        component_index[o] = nil
    end
end

function world_delete(world: World, entity: i53)
	local entityIndex = world.entityIndex

	local record = entityIndex.sparse[entity]
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
	entityIndex.sparse[entity] = nil
end

local function world_contains(world: World, entity)

    return world.entityIndex.sparse[entity]
end

type CompatibleArchetype = { archetype: Archetype, indices: { number } }

local function noop()
end

local function Arm(query, ...)
    return query
end

local world_query
do
    local empty_list = {}
    local EmptyQuery = {
       	__iter = function()
            return noop
       	end,
        iter = function()
            return noop
        end,
        drain = Arm,
       	next = noop,
       	replace = noop,
        with = Arm,
       	without = Arm,
        archetypes = function()
            return empty_list
        end,
    }

    setmetatable(EmptyQuery, EmptyQuery)

    local function world_query_replace_values(row, columns, ...)
       	for i, column in columns do
      		column[row] = select(i, ...)
       	end
    end

    function world_query(world: World, ...)
            -- breaking
       	if (...) == nil then
      		error("Missing components")
       	end

        local compatible_archetypes = {}
       	local length = 0

        local ids = { ... }
        local A, B, C, D, E, F, G, H, I = ...
        local a, b, c, d, e, f, g, h

       	local archetypes = world.archetypes

       	local idr: ArchetypeMap
       	local componentIndex = world.componentIndex

       	for _, id in ids do
      		local map = componentIndex[id]
      		if not map then
     			return EmptyQuery
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
            return EmptyQuery
        end

        local lastArchetype = 1
        local archetype
        local columns
        local entities
        local i
        local queryOutput

        local world_query_iter_next

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
   					local records = archetype.records
   					a = columns[records[A].column]
                end

				local row = i
				i-=1

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
   					local records = archetype.records
   					a = columns[records[A].column]
   					b = columns[records[B].column]
                end

				local row = i
				i-=1

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
   					local records = archetype.records
   					a = columns[records[A].column]
   					b = columns[records[B].column]
   					c = columns[records[C].column]
     			end

				local row = i
				i-=1

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
   					local records = archetype.records
   					a = columns[records[A].column]
   					b = columns[records[B].column]
   					c = columns[records[C].column]
   					d = columns[records[D].column]
				end

				local row = i
				i-=1

				return entityId, a[row], b[row], c[row], d[row]
            end
  		else
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
				i-=1

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

        local init = false
        local drain = false

        local function query_init(query)
            if init and drain then
                return true
            end

            init = true
            lastArchetype = 1
           	archetype = compatible_archetypes[lastArchetype]

           	if not archetype then
          		return false
           	end

           	queryOutput = {}

            entities = archetype.entities
           	i = #entities
            columns = archetype.columns

            local records = archetype.records
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
            return true
        end

        local function world_query_without(query, ...)
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
                    length -= 1
                end
      		end

            if length == 0 then
                return EmptyQuery
            end

      		return query
        end

        local function world_query_replace(query, fn: (...any) -> (...any))
            query_init(query)

            for i, archetype in compatible_archetypes do
          		local columns = archetype.columns
                local records = archetype.records
          		for row in archetype.entities do
              		if not B then
             			local va = columns[records[A].column]
             			local pa = fn(va[row])

             			va[row] = pa
              		elseif not C then
             			local va = columns[records[A].column]
             			local vb = columns[records[B].column]

             			va[row], vb[row] = fn(va[row], vb[row])
              		elseif not D then
             			local va = columns[records[A].column]
             			local vb = columns[records[B].column]
             			local vc = columns[records[C].column]

             			va[row], vb[row], vc[row] = fn(va[row], vb[row], vc[row])
              		elseif not E then
             			local va = columns[records[A].column]
             			local vb = columns[records[B].column]
             			local vc = columns[records[C].column]
                        local vd = columns[records[D].column]

             			va[row], vb[row], vc[row], vd[row] = fn(
             			    va[row], vb[row], vc[row], vd[row])
              		else
                        for j, id in ids do
                            local tr = records[id]
                 			queryOutput[j] = columns[tr.column][row]
                  		end
             			world_query_replace_values(row, columns,
                            fn(unpack(queryOutput)))
              		end
                end
            end
        end

        local function world_query_with(query, ...)
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
                    length -= 1
     			end
            end
            if length == 0 then
                return EmptyQuery
            end
            return query
        end

        -- Meant for directly iterating over archetypes to minimize
        -- function call overhead. Should not be used unless iterating over
        -- hundreds of thousands of entities in bulk.
        local function world_query_archetypes()
            return compatible_archetypes
        end

        local function world_query_drain(query)
            drain = true
            if query_init(query) then
                return query
            end
            return EmptyQuery
        end

        local function world_query_iter(query)
            query_init(query)
            return world_query_iter_next
        end

        local function world_query_next(world)
            if not drain then
                error("Did you forget to call query:drain()?")
            end
            return world_query_iter_next(world)
        end

        local it = {
            __iter = world_query_iter,
            iter = world_query_iter,
            drain = world_query_drain,
            next = world_query_next,
            with = world_query_with,
            without = world_query_without,
            replace = world_query_replace,
            archetypes = world_query_archetypes
        } :: any

        setmetatable(it, it)

        return it
    end
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

	self.ROOT_ARCHETYPE = archetype_create(self, {})

	for i = HI_COMPONENT_ID + 1, EcsRest do
	   -- Initialize built-in components
		entity_index_new_id(self.entityIndex, i)
	end

	world_add(self, EcsChildOf,
	   ECS_PAIR(EcsOnDeleteTarget, EcsDelete))

	return self
end

export type Pair = number

type Item = () -> (number, ...any)

export type Entity<T = nil> = number & {__DO_NOT_USE_OR_YOU_WILL_BE_FIRED: T }

type Iter<T...> = (query: Query<T...>) -> () -> (Entity, T...)

type Query<T...> = typeof(setmetatable({}, {
    __iter = (nil :: any) :: Iter<T...>
})) & {
    iter: Iter<T...>,
    next: Item,
    with: (Query<T...>) -> Query<T...>,
    without: (Query<T...>, ...i53) -> Query<T...>,
    replace: (Query<T...>, <U...>(T...) -> (U...)) -> (),
    archetypes: () -> { Archetype },
}

type World = {
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
		--- `world:target(id, ChildOf(parent))`, you will obtain the parent entity.
		target: (self: World, id: Entity, relation: Entity) -> Entity?,
		--- Deletes an entity and all it's related components and relationships.
		delete: (self: World, id: Entity) -> (),

		--- Adds a component to the entity with no value
		add: <T>(self: World, id: Entity, component: Entity<T>) -> (),
		--- Assigns a value to a component on the given entity
		set: <T>(self: World, id: Entity, component: Entity<T>, data: T) -> (),

		-- Clears an entity from the world
		clear: (self: World, id: Entity) -> (),
		--- Removes a component from the given entity
		remove: (self: World, id: Entity, component: Entity) -> (),
		--- Retrieves the value of up to 4 components. These values may be nil.
		get: (<A>(self: World, id: any, Entity<A>) -> A)
			& (<A, B>(self: World, id: Entity, Entity<A>, Entity<B>) -> (A, B))
			& (<A, B, C>(self: World, id: Entity, Entity<A>, Entity<B>, Entity<C>) -> (A, B, C))
			& <A, B, C, D>(self: World, id: Entity, Entity<A>, Entity<B>, Entity<C>, Entity<D>) -> (A, B, C, D),

		--- Searches the world for entities that match a given query
		query: (<A>(self: World, Entity<A>) -> Query<A>)
			& (<A, B>(self: World, Entity<A>, Entity<B>) -> Query<A, B>)
			& (<A, B, C>(self: World, Entity<A>, Entity<B>, Entity<C>) -> Query<A, B, C>)
			& (<A, B, C, D>(self: World, Entity<A>, Entity<B>, Entity<C>, Entity<D>) -> Query<A, B, C, D>)
			& (<A, B, C, D, E>(
				self: World,
				Entity<A>,
				Entity<B>,
				Entity<C>,
				Entity<D>,
				Entity<E>
			) -> Query<A, B, C, D, E>)
			& (<A, B, C, D, E, F>(
				self: World,
				Entity<A>,
				Entity<B>,
				Entity<C>,
				Entity<D>,
				Entity<E>,
				Entity<F>
			) -> Query<A, B, C, D, E, F>)
			& (<A, B, C, D, E, F, G>(
				self: World,
				Entity<A>,
				Entity<B>,
				Entity<C>,
				Entity<D>,
				Entity<E>,
				Entity<F>,
				Entity<G>
			) -> Query<A, B, C, D, E, F, G>)
			& (<A, B, C, D, E, F, G, H>(
				self: World,
				Entity<A>,
				Entity<B>,
				Entity<C>,
				Entity<D>,
				Entity<E>,
				Entity<F>,
				Entity<G>,
				Entity<H>,
				...Entity<any>
			) -> Query<A, B, C, D, E, F, G, H>),
	}

return {
	World = World :: { new: () -> World },

	OnAdd = EcsOnAdd :: Entity,
	OnRemove = EcsOnRemove :: Entity,
	OnSet = EcsOnSet :: Entity,
	ChildOf = EcsChildOf :: Entity,
	Component = EcsComponent :: Entity,
	Wildcard = EcsWildcard :: Entity,
	w = EcsWildcard :: Entity,
	OnDeleteTarget = EcsOnDeleteTarget :: Entity,
	Delete = EcsDelete :: Entity,
	Rest = EcsRest :: Entity,

	pair = (ECS_PAIR :: any) :: <R, T>(pred: Entity, obj: Entity) -> number,

	-- Inwards facing API for testing
	ECS_ID = ECS_ENTITY_T_LO,
	ECS_GENERATION_INC = ECS_GENERATION_INC,
	ECS_GENERATION = ECS_GENERATION,
	ECS_ID_IS_WILDCARD = ECS_ID_IS_WILDCARD,

	IS_PAIR = ECS_IS_PAIR,
	pair_first = ecs_pair_first,
	pair_second = ecs_pair_second,
	entity_index_get_alive = entity_index_get_alive,
}
