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


type Archetype = {
	id: number,
	edges: { [i53]: ArchetypeEdge },
	types: Ty,
	type: string | number,
	entities: { number },
	columns: { Column },
	records: { [number]: number },
}
type Record = {
	archetype: Archetype,
	row: number,
	dense: i24,
	componentRecord: ArchetypeMap,
}

type EntityIndex = { dense: { [i24]: i53 }, sparse: { [i53]: Record } }

type ArchetypeRecord = number
--[[
TODO:
{
	index: number,
	count: number,
	column: number
}

]]

type ArchetypeMap = {
	cache: { ArchetypeRecord },
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
local EcsRest 				= HI_COMPONENT_ID + 7

local ECS_PAIR_FLAG 		= 0x8
local ECS_ID_FLAGS_MASK 	= 0x10
local ECS_ENTITY_MASK 		= bit32.lshift(1, 24)
local ECS_GENERATION_MASK 	= bit32.lshift(1, 16)

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
local function ecs_pair_relation(entityIndex, e)
	return entity_index_get_alive(entityIndex, ECS_ENTITY_T_HI(e))
end

-- ECS_PAIR_SECOND gets the relationship / pred / LOW bits
local function ecs_pair_object(entityIndex, e)
	return entity_index_get_alive(entityIndex, ECS_ENTITY_T_LO(e))
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

local function archetype_move(entityIndex: EntityIndex, to: Archetype,
	destinationRow: i24, from: Archetype, sourceRow: i24)

	local columns = from.columns
	local sourceEntities = from.entities
	local destinationEntities = to.entities
	local destinationColumns = to.columns
	local tr = to.records
	local types = from.types

	for i, column in columns do
		-- Retrieves the new column index from the source archetype's record from each component
		-- We have to do this because the columns are tightly packed and indexes may not correspond to each other.
		local targetColumn = destinationColumns[tr[types[i]]]

		-- Sometimes target column may not exist, e.g. when you remove a component.
		if targetColumn then
			targetColumn[destinationRow] = column[sourceRow]
		end
		-- If the entity is the last row in the archetype then swapping it would be meaningless.
		local last = #column
		if sourceRow ~= last then
			-- Swap rempves columns to ensure there are no holes in the archetype.
			column[sourceRow] = column[last]
		end
		column[last] = nil
	end

	local sparse = entityIndex.sparse
	local movedAway = #sourceEntities

	-- Move the entity from the source to the destination archetype.
	-- Because we have swapped columns we now have to update the records
	-- corresponding to the entities' rows that were swapped.
	local e1 = sourceEntities[sourceRow]
	local e2 = sourceEntities[movedAway]

	if sourceRow ~= movedAway then
		sourceEntities[sourceRow] = e2
	end

	sourceEntities[movedAway] = nil :: any
	destinationEntities[destinationRow] = e1

	local record1 = sparse[e1]
	local record2 = sparse[e2]

	record1.row = destinationRow
	record2.row = sourceRow
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

local function id_record_ensure(
	componentIndex: ComponentIndex,
	componentId: number
): ArchetypeMap
	local archetypesMap = componentIndex[componentId]

	if not archetypesMap then
		archetypesMap = ({ size = 0, cache = {} } :: any) :: ArchetypeMap
		componentIndex[componentId] = archetypesMap
	end

	return archetypesMap
end

local function ECS_ID_IS_WILDCARD(e: i53): boolean
	assert(ECS_IS_PAIR(e))
	local first = ECS_ENTITY_T_HI(e)
	local second = ECS_ENTITY_T_LO(e)
	return first == EcsWildcard or second == EcsWildcard
end

local function archetype_of(world: any, types: { i24 }, prev: Archetype?): Archetype
	local ty = hash(types)

	local id = world.nextArchetypeId + 1
	world.nextArchetypeId = id

	local length = #types
	local columns = (table.create(length) :: any) :: { Column }
	local componentIndex = world.componentIndex

	local records = {}
	for i, componentId in types do
		local idr = id_record_ensure(componentIndex, componentId)
		idr.cache[id] = i
		idr.size += 1
		records[componentId] = i
		if ECS_IS_PAIR(componentId) then
			local relation = ecs_pair_relation(world.entityIndex, componentId)
			local object = ecs_pair_object(world.entityIndex, componentId)

			local r = ECS_PAIR(relation, EcsWildcard)
			local idr_r = id_record_ensure(componentIndex, r)

			local o = ECS_PAIR(EcsWildcard, object)
			local idr_o = id_record_ensure(componentIndex, o)

			records[r] = i
			records[o] = i

			idr_r.cache[id] = i
			idr_o.cache[id] = i

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

export type World = {
	archetypeIndex: { [string]: Archetype },
	archetypes: Archetypes,
	componentIndex: ComponentIndex,
	entityIndex: EntityIndex,
	nextArchetypeId: number,
	nextComponentId: number,
	nextEntityId: number,
	ROOT_ARCHETYPE: Archetype
}

local function world_entity(world: World): i53
	local entityId = world.nextEntityId + 1
	world.nextEntityId = entityId
	return entity_index_new_id(world.entityIndex, entityId + EcsRest)
end

-- TODO:
-- should have an additional `nth` parameter which selects the nth target
-- this is important when an entity can have multiple relationships with the same target
local function world_target(world: World, entity: i53, relation: i24--[[, nth: number]]): i24?
	local entityIndex = world.entityIndex
	local record = entityIndex.sparse[entity]
	local archetype = record.archetype
	if not archetype then
		return nil
	end

	local componentRecord = world.componentIndex[ECS_PAIR(relation, EcsWildcard)]
	if not componentRecord then
		return nil
	end

	local archetypeRecord = componentRecord.cache[archetype.id]
	if not archetypeRecord then
		return nil
	end

	return ecs_pair_object(entityIndex, archetype.types[archetypeRecord])
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

	return archetype_of(world, types, prev)
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

	local dst_type = table.clone(node.types) :: { i53 }
	local at = find_insert(types, id)
	if at == -1 then
		-- If it finds a duplicate, it just means it is the same archetype so it can return it
		-- directly instead of needing to hash types for a lookup to the archetype.
		return node
	end
	table.insert(dst_type, at, id)

	return archetype_ensure(world, dst_type, node)
end

local function edge_ensure(archetype: Archetype, componentId: i53): ArchetypeEdge
	local edges = archetype.edges
	local edge = edges[componentId]
	if not edge then
		edge = {} :: any
		edges[componentId] = edge
	end
	return edge
end

local function archetype_traverse_add(world: World, componentId: i53, from: Archetype): Archetype
	from = from or world.ROOT_ARCHETYPE

	local edge = edge_ensure(from, componentId)
	local add = edge.add
	if not add then
		-- Save an edge using the component ID to the archetype to allow
		-- faster traversals to adjacent archetypes.
		add = find_archetype_with(world, from, componentId)
		edge.add = add :: never
	end

	return add
end

local function world_add(world: World, entityId: i53, componentId: i53)
	local entityIndex = world.entityIndex
	local record = entityIndex.sparse[entityId]
	local from = record.archetype
	local to = archetype_traverse_add(world, componentId, from)
	if from == to then
		return
	end
	if from then
		entity_move(entityIndex, entityId, record, to)
	else
		if #to.types > 0 then
			new_entity(entityId, record, to)
		end
	end
end

-- Symmetric like `World.add` but idempotent
local function world_set(world: World, entityId: i53, componentId: i53, data: unknown)
	local record = world.entityIndex.sparse[entityId]
	local from = record.archetype
	local to = archetype_traverse_add(world, componentId, from)

	if from == to then
		-- If the archetypes are the same it can avoid moving the entity
		-- and just set the data directly.
		local archetypeRecord = to.records[componentId]
		from.columns[archetypeRecord][record.row] = data
		-- Should fire an OnSet event here.
		return
	end

	if from then
		-- If there was a previous archetype, then the entity needs to move the archetype
		entity_move(world.entityIndex, entityId, record, to)
	else
		if #to.types > 0 then
			-- When there is no previous archetype it should create the archetype
			new_entity(entityId, record, to)
		end
	end

	local archetypeRecord = to.records[componentId]
	to.columns[archetypeRecord][record.row] = data
end

local function world_component(world: World): i53
	local componentId = world.nextComponentId + 1
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


local function archetype_traverse_remove(world: World, componentId: i53, from: Archetype): Archetype
	local edge = edge_ensure(from, componentId)

	local remove = edge.remove
	if not remove then
		local to = table.clone(from.types) :: { i53 }
		local at = table.find(to, componentId)
		if not at then
			return from
		end
		table.remove(to, at)
		remove = archetype_ensure(world, to, from)
		edge.remove = remove :: never
	end

	return remove
end

local function world_remove(world: World, entityId: i53, componentId: i53)
	local entityIndex = world.entityIndex
	local record = entityIndex.sparse[entityId]
	local sourceArchetype = record.archetype
	if not sourceArchetype then
	   return
	end
	local destinationArchetype = archetype_traverse_remove(world, componentId, sourceArchetype)

	if sourceArchetype and not (sourceArchetype == destinationArchetype) then
		entity_move(entityIndex, entityId, record, destinationArchetype)
	end
end

-- should reuse this logic in World.set instead of swap removing in transition archetype
local function columns_destruct(columns: { Column }, count: number, row: number)
	if row == count then
		for _, column in columns do
			column[count] = nil
		end
	else
		for _, column in columns do
			column[row] = column[count]
			column[count] = nil
		end
	end
end

local function archetype_delete(world: World, id: i53)
	local componentIndex = world.componentIndex
	local archetypesMap = componentIndex[id]
	local archetypes = world.archetypes

	if archetypesMap then
		for archetypeId in archetypesMap.cache do
			for _, entity in archetypes[archetypeId].entities do
				world_remove(world, entity, id)
			end
		end

		componentIndex[id] = nil :: any
	end
end

local function world_delete(world: World, entityId: i53)
	local record = world.entityIndex.sparse[entityId]
	if not record then
		return
	end
	local entityIndex = world.entityIndex
	local sparse, dense = entityIndex.sparse, entityIndex.dense
	local archetype = record.archetype
	local row = record.row

	archetype_delete(world, entityId)
	-- TODO: should traverse linked )component records to pairs including entityId
	archetype_delete(world, ECS_PAIR(entityId, EcsWildcard))
	archetype_delete(world, ECS_PAIR(EcsWildcard, entityId))

	if archetype then
		local entities = archetype.entities
		local last = #entities

		if row ~= last then
			local entityToMove = entities[last]
			dense[record.dense] = entityToMove
			sparse[entityToMove] = record
		end

		entities[row], entities[last] = entities[last], nil :: any

		local columns = archetype.columns

		columns_destruct(columns, last, row)
	end

	sparse[entityId] = nil :: any
	dense[#dense] = nil :: any

end

local function world_clear(world: World, entityId: i53)
	--TODO: use sparse_get (stashed)
	local record = world.entityIndex.sparse[entityId]
	if not record then
		return
	end

	local ROOT_ARCHETYPE = world.ROOT_ARCHETYPE
	local archetype = record.archetype

	if archetype == nil or archetype == ROOT_ARCHETYPE then
		return
	end

	entity_move(world.entityIndex, entityId, record, ROOT_ARCHETYPE)
end

local world_get: (world: World, entityId: i53, a: i53, b: i53?, c: i53?, d: i53?, e: i53?) -> (...any)
do
    -- Keeping the function as small as possible to enable inlining
    local function fetch(id: i24, records, columns, row): any
    	local tr = records[id]

    	if not tr then
    		return nil
    	end

    	return columns[tr][row]
    end

    function world_get(world: World, entityId: i53, a: i53, b: i53?, c: i53?, d: i53?, e: i53?): ...any
    	local id = entityId
    	local record = world.entityIndex.sparse[id]
    	if not record then
    		return nil
    	end

    	local archetype = record.archetype
    	if not archetype then
    	   return nil
    	end

    	local tr = archetype.records
    	local columns = archetype.columns
    	local row = record.row

    	local va = fetch(a, tr, columns, row)

    	if b == nil then
    		return va
    	elseif c == nil then
    		return va, fetch(b, tr, columns, row)
    	elseif d == nil then
    		return va, fetch(b, tr, columns, row), fetch(c, tr, columns, row)
    	elseif e == nil then
    		return va, fetch(b, tr, columns, row), fetch(c, tr, columns, row), fetch(d, tr, columns, row)
    	else
    		error("args exceeded")
    	end
    end
end

local world_has: (world: World, entityId: number, ...i53) -> boolean
do
    function world_has(world, entity_id, ...)
       	local id = entity_id
       	local record = world.entityIndex.sparse[id]
       	if not record then
      		return false
       	end

       	local archetype = record.archetype
       	if not archetype then
    	   return false
       	end

        local tr = archetype.records

        for i = 1, select("#", ...) do
            if not tr[select(i, ...)] then
                return false
            end
        end

        return true
    end
end

type Item = () -> (number, ...any)
export type Query = typeof({
    __iter = function():  Item
        return function()
            return 1
        end
    end,
}) & {
    next: Item,
    without: (Query) -> Query,
    replace: (Query, (...any) -> (...any)) -> ()
}

type CompatibleArchetype = { archetype: Archetype, indices: { number } }

local world_query: (World, ...i53) -> Query
do

    local noop: Item = function()
   	    return nil :: any
    end

    local EmptyQuery: Query = {
       	__iter = function(): Item
            return noop
       	end,
       	next = noop :: Item,
       	replace = noop :: (Query, ...any) -> (),
       	without = function(self: Query, ...)
            return self
       	end
    }

    setmetatable(EmptyQuery, EmptyQuery)

    local lastArchetype: number
    local archetype: Archetype
    local queryOutput: { any }
    local queryLength: number
    local entities: { number }
    local i: number

    local compatible_archetypes: { Archetype }
    local column_indices: { { number} }
    local ids: { number }
    local tr
    local columns

    local function world_query_next(): any
        local entityId = entities[i]
  		while entityId == nil do
 			lastArchetype += 1
 			archetype = compatible_archetypes[lastArchetype]
 			if not archetype then
                return nil
            end
            tr = column_indices[lastArchetype]
            columns = archetype.columns
            entities = archetype.entities
 			i = #entities
 			entityId = entities[i]
  		end

  		local row = i
  		i-=1

  		if queryLength == 1 then
 			return entityId, columns[tr[1]][row]
  		elseif queryLength == 2 then
 			return entityId, columns[tr[1]][row], columns[tr[2]][row]
  		elseif queryLength == 3 then
 			return entityId, columns[tr[1]][row], columns[tr[2]][row], columns[tr[3]][row]
  		elseif queryLength == 4 then
 			return entityId, columns[tr[1]][row], columns[tr[2]][row], columns[tr[3]][row], columns[tr[4]][row]
  		elseif queryLength == 5 then
 			return entityId,
    				columns[tr[1]][row],
    				columns[tr[2]][row],
    				columns[tr[3]][row],
    				columns[tr[4]][row],
    				columns[tr[5]][row]
  		elseif queryLength == 6 then
 			return entityId,
    				columns[tr[1]][row],
    				columns[tr[2]][row],
    				columns[tr[3]][row],
    				columns[tr[4]][row],
    				columns[tr[5]][row],
    				columns[tr[6]][row]
  		elseif queryLength == 7 then
 			return entityId,
    				columns[tr[1]][row],
    				columns[tr[2]][row],
    				columns[tr[3]][row],
    				columns[tr[4]][row],
    				columns[tr[5]][row],
    				columns[tr[6]][row],
    				columns[tr[7]][row]
  		elseif queryLength == 8 then
 			return entityId,
    				columns[tr[1]][row],
    				columns[tr[2]][row],
    				columns[tr[3]][row],
    				columns[tr[4]][row],
    				columns[tr[5]][row],
    				columns[tr[6]][row],
    				columns[tr[7]][row],
    				columns[tr[8]][row]
  		end

  		for j in ids do
 			queryOutput[j] = columns[tr[j]][row]
  		end

  		return entityId, unpack(queryOutput, 1, queryLength)
    end

    local function world_query_iter()
        return world_query_next
    end

    local function world_query_without(self, ...)
        local withoutComponents = { ... }
  		for i = #compatible_archetypes, 1, -1 do
 			local archetype = compatible_archetypes[i]
 			local records = archetype.records
 			local shouldRemove = false

 			for _, componentId in withoutComponents do
                if records[componentId] then
   					shouldRemove = true
   					break
                end
 			end

 			if shouldRemove then
                local last = #compatible_archetypes
                if last ~= i then
                    compatible_archetypes[i] = compatible_archetypes[last]
                    column_indices[i] = column_indices[last]
                end
                compatible_archetypes[last] = nil
                column_indices[last] = nil
 			end
  		end

        lastArchetype = 1
        archetype = compatible_archetypes[lastArchetype]

  		if not archetype then
 			return EmptyQuery
  		end

  		return self
    end

    local function world_query_replace_values(row, columns, ...)
       	for i, column in columns do
      		column[row] = select(i, ...)
       	end
    end

    local function world_query_replace(_, fn: (...any) -> (...any))
        for i, archetype in compatible_archetypes do
      		local tr = column_indices[i]
      		local columns = archetype.columns

      		for row in archetype.entities do
          		if queryLength == 1 then
         			local a = columns[tr[1]]
         			local pa = fn(a[row])

         			a[row] = pa
          		elseif queryLength == 2 then
         			local a = columns[tr[1]]
         			local b = columns[tr[2]]

         			a[row], b[row] = fn(a[row], b[row])
          		elseif queryLength == 3 then
         			local a = columns[tr[1]]
         			local b = columns[tr[2]]
         			local c = columns[tr[3]]

         			a[row], b[row], c[row] = fn(a[row], b[row], c[row])
          		elseif queryLength == 4 then
         			local a = columns[tr[1]]
         			local b = columns[tr[2]]
         			local c = columns[tr[3]]
         			local d = columns[tr[4]]

         			a[row], b[row], c[row], d[row] = fn(
         			    a[row], b[row], c[row], d[row])
          		else
         			for i = 1, queryLength do
         			    queryOutput[i] = columns[tr[i]][row]
         			end
         			world_query_replace_values(row, columns,
                        fn(unpack(queryOutput)))
          		end
            end
        end
    end

    local function world_query_with(query, ...)
        local ids = { ... }
        for i = #compatible_archetypes, 1, -1 do
 			local archetype = compatible_archetypes[i]
 			local records = archetype.records
 			local shouldRemove = false

 			for _, id in ids do
 			    if not records[id] then
    				shouldRemove = true
    				break
 			    end
 			end

 			if shouldRemove then
 			    table.remove(compatible_archetypes, i)
 			end
        end

        if #compatible_archetypes == 0 then
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

    local it = {
        __iter = world_query_iter,
        next = world_query_next,
        with = world_query_with,
        without = world_query_without,
        replace = world_query_replace,
        archetypes = world_query_archetypes
    } :: any

    setmetatable(it, it)

    function world_query(world: World, ...: any): Query
    	-- breaking
    	if (...) == nil then
    		error("Missing components")
    	end

    	local indices = {}
        compatible_archetypes = {}
    	local length = 0

        local components = { ... } :: any
    	local archetypes = world.archetypes

    	local firstArchetypeMap: ArchetypeMap
    	local componentIndex = world.componentIndex

    	for _, componentId in components do
    		local map = componentIndex[componentId]
    		if not map then
    			return EmptyQuery
    		end

    		if firstArchetypeMap == nil or map.size < firstArchetypeMap.size then
    			firstArchetypeMap = map
    		end
    	end

    	for id in firstArchetypeMap.cache do
    		local compatibleArchetype = archetypes[id]
    		local archetypeRecords = compatibleArchetype.records

    		local records = {}
    		local skip = false

    		for i, componentId in components do
    			local index = archetypeRecords[componentId]
    			if not index then
    				skip = true
    				break
    			end
    			-- index should be index.offset
    			records[i] = index
    		end

    		if skip then
    			continue
    		end

    		length += 1
    		compatible_archetypes[length] = compatibleArchetype
    		indices[length] = records
    	end

        column_indices = indices
        ids = components

        lastArchetype = 1
       	archetype = compatible_archetypes[lastArchetype]

       	if not archetype then
      		return EmptyQuery
       	end

       	queryOutput = {}
        queryLength = #ids

        entities = archetype.entities
       	i = #entities
        tr = column_indices[lastArchetype]
        columns = archetype.columns

       	return it
    end
end

type WorldIterator = (() -> (i53, { [unknown]: unknown? })) & (() -> ()) & (() -> i53)
-- __nominal_type_dont_use could not be any or T as it causes a type error
-- or produces a union
export type Entity<T = any> = number & { __nominal_type_dont_use: T }
export type Pair = number

export type QueryShim<T...> = typeof(setmetatable({
	without = function(...): QueryShim<T...>
		return nil :: any
	end,
}, {
	__iter = function(): () -> (number, T...)
		return nil :: any
	end,
}))

export type WorldShim = typeof(setmetatable(
	{} :: {

		--- Creates a new entity
		entity: (WorldShim) -> Entity,
		--- Creates a new entity located in the first 256 ids.
		--- These should be used for static components for fast access.
		component: <T>(WorldShim) -> Entity<T>,
		--- Gets the target of an relationship. For example, when a user calls
		--- `world:target(id, ChildOf(parent))`, you will obtain the parent entity.
		target: (WorldShim, id: Entity, relation: Entity) -> Entity?,
		--- Deletes an entity and all it's related components and relationships.
		delete: (WorldShim, id: Entity) -> (),

		--- Adds a component to the entity with no value
		add: <T>(WorldShim, id: Entity, component: Entity<T>) -> (),
		--- Assigns a value to a component on the given entity
		set: <T>(WorldShim, id: Entity, component: Entity<T>, data: T) -> (),

		-- Clears an entity from the world
		clear: (WorldShim, id: Entity) -> (),
		--- Removes a component from the given entity
		remove: (WorldShim, id: Entity, component: Entity) -> (),
		--- Retrieves the value of up to 4 components. These values may be nil.
		get: (<A>(WorldShim, id: Entity, Entity<A>) -> A)
			& (<A, B>(WorldShim, id: Entity, Entity<A>, Entity<B>) -> (A, B))
			& (<A, B, C>(WorldShim, id: Entity, Entity<A>, Entity<B>, Entity<C>) -> (A, B, C))
			& <A, B, C, D>(WorldShim, id: Entity, Entity<A>, Entity<B>, Entity<C>, Entity<D>) -> (A, B, C, D),

		has: (WorldShim, Entity, ...Entity) -> boolean,

		--- Searches the world for entities that match a given query
		query: (<A>(WorldShim, Entity<A>) -> QueryShim<A>)
			& (<A, B>(WorldShim, Entity<A>, Entity<B>) -> QueryShim<A, B>)
			& (<A, B, C>(WorldShim, Entity<A>, Entity<B>, Entity<C>) -> QueryShim<A, B, C>)
			& (<A, B, C, D>(WorldShim, Entity<A>, Entity<B>, Entity<C>, Entity<D>) -> QueryShim<A, B, C, D>)
			& (<A, B, C, D, E>(
				WorldShim,
				Entity<A>,
				Entity<B>,
				Entity<C>,
				Entity<D>,
				Entity<E>
			) -> QueryShim<A, B, C, D, E>)
			& (<A, B, C, D, E, F>(
				WorldShim,
				Entity<A>,
				Entity<B>,
				Entity<C>,
				Entity<D>,
				Entity<E>,
				Entity<F>
			) -> QueryShim<A, B, C, D, E, F>)
			& (<A, B, C, D, E, F, G>(
				WorldShim,
				Entity<A>,
				Entity<B>,
				Entity<C>,
				Entity<D>,
				Entity<E>,
				Entity<F>,
				Entity<G>
			) -> QueryShim<A, B, C, D, E, F, G>)
			& (<A, B, C, D, E, F, G, H>(
				WorldShim,
				Entity<A>,
				Entity<B>,
				Entity<C>,
				Entity<D>,
				Entity<E>,
				Entity<F>,
				Entity<G>,
				Entity<H>
			) -> QueryShim<A, B, C, D, E, F, G, H>)
			& (<A, B, C, D, E, F, G, H, I>(
				WorldShim,
				Entity<A>,
				Entity<B>,
				Entity<C>,
				Entity<D>,
				Entity<E>,
				Entity<F>,
				Entity<G>,
				Entity<H>,
				Entity<I>
			) -> QueryShim<A, B, C, D, E, F, G, H, I>)
			& (<A, B, C, D, E, F, G, H, I, J>(
				WorldShim,
				Entity<A>,
				Entity<B>,
				Entity<C>,
				Entity<D>,
				Entity<E>,
				Entity<F>,
				Entity<G>,
				Entity<H>,
				Entity<I>,
				Entity<J>
			) -> QueryShim<A, B, C, D, E, F, G, H, I, J>)
			& (<A, B, C, D, E, F, G, H, I, J, K>(
				WorldShim,
				Entity<A>,
				Entity<B>,
				Entity<C>,
				Entity<D>,
				Entity<E>,
				Entity<F>,
				Entity<G>,
				Entity<H>,
				Entity<I>,
				Entity<J>,
				Entity<K>,
				...Entity<any>
			) -> QueryShim<A, B, C, D, E, F, G, H, I, J, K>),
	},
	{} :: {
		__iter: (world: WorldShim) -> () -> (number, { [unknown]: unknown? }),
	}
))

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

function World.new()
    local self = setmetatable({
        archetypeIndex = {} :: { [string]: Archetype },
        archetypes = {} :: Archetypes,
  		componentIndex = {} :: ComponentIndex,
  		entityIndex = {
 			dense = {} :: { [i24]: i53 },
 			sparse = {} :: { [i53]: Record },
  		} :: EntityIndex,
  		hooks = {
 			[EcsOnAdd] = {},
  		},
  		nextArchetypeId = 0,
  		nextComponentId = 0,
  		nextEntityId = 0,
  		ROOT_ARCHETYPE = (nil :: any) :: Archetype,
    }, World)

	self.ROOT_ARCHETYPE = archetype_of(self, {})

	for i = HI_COMPONENT_ID + 1, EcsRest do
	   -- Initialize built-in components
		entity_index_new_id(self.entityIndex, i)
	end

	return self
end

return {
	World = World :: { new: () -> WorldShim } ,

	OnAdd = EcsOnAdd :: Entity,
	OnRemove = EcsOnRemove :: Entity,
	OnSet = EcsOnSet :: Entity,
	ChildOf = EcsChildOf,
	Component = EcsComponent,
	Wildcard = EcsWildcard :: Entity,
	w = EcsWildcard :: Entity,
	Rest = EcsRest,

	pair = (ECS_PAIR :: any) :: <R, T>(pred: Entity, obj: Entity) -> number,

	-- Inwards facing API for testing
	IS_PAIR = ECS_IS_PAIR,
	ECS_ID = ECS_ENTITY_T_LO,
	ECS_GENERATION_INC = ECS_GENERATION_INC,
	ECS_GENERATION = ECS_GENERATION,

	ecs_pair_relation = ecs_pair_relation,
	ecs_pair_object = ecs_pair_object,
	entity_index_get_alive = entity_index_get_alive,
}
