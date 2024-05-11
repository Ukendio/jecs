--!optimize 2
--!native
--!strict
--draft 4

type i53 = number
type i24 = number

type Ty = {i53}
type ArchetypeId = number

type Column = {any}

type Archetype = {
	id: number,
	edges: {
		[i24]: {
			add: Archetype,
			remove: Archetype,
		},
	},
	types: Ty,
	type: string | number,
	entities: {number},
	columns: {Column},
	records: {},
}

type Record = {
	archetype: Archetype,
	row: number,
	dense: i24,
}

type EntityIndex = {dense: {[i24]: i53}, sparse: {[i53]: Record}}
type ComponentIndex = {[i24]: ArchetypeMap}

type ArchetypeRecord = number
type ArchetypeMap = {sparse: {[ArchetypeId]: ArchetypeRecord}, size: number}
type Archetypes = {[ArchetypeId]: Archetype}

type ArchetypeDiff = {
	added: Ty,
	removed: Ty,
}

local HI_COMPONENT_ID = 256
local ON_ADD = HI_COMPONENT_ID + 1
local ON_REMOVE = HI_COMPONENT_ID + 2
local ON_SET = HI_COMPONENT_ID + 3
local REST = HI_COMPONENT_ID + 4

local function transitionArchetype(
	entityIndex: EntityIndex,
	to: Archetype,
	destinationRow: i24,
	from: Archetype,
	sourceRow: i24
)
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

	sourceEntities[movedAway] = nil
	destinationEntities[destinationRow] = e1

	local record1 = sparse[e1]
	local record2 = sparse[e2]

	record1.row = destinationRow
	record2.row = sourceRow
end

local function archetypeAppend(entity: number, archetype: Archetype): number
	local entities = archetype.entities
	local length = #entities + 1
	entities[length] = entity
	return length
end

local function newEntity(entityId: i53, record: Record, archetype: Archetype)
	local row = archetypeAppend(entityId, archetype)
	record.archetype = archetype
	record.row = row
	return record
end

local function moveEntity(entityIndex, entityId: i53, record: Record, to: Archetype)
	local sourceRow = record.row
	local from = record.archetype
	local destinationRow = archetypeAppend(entityId, to)
	transitionArchetype(entityIndex, to, destinationRow, from, sourceRow)
	record.archetype = to
	record.row = destinationRow
end

local function hash(arr): string | number
	return table.concat(arr, "_")
end

local function createArchetypeRecords(componentIndex: ComponentIndex, to: Archetype, _from: Archetype?)
	local destinationIds = to.types
	local records = to.records
	local id = to.id

	for i, destinationId in destinationIds do
		local archetypesMap = componentIndex[destinationId]

		if not archetypesMap then
			archetypesMap = {size = 0, sparse = {}}
			componentIndex[destinationId] = archetypesMap
		end

		archetypesMap.sparse[id] = i
		records[destinationId] = i
	end
end

local function archetypeOf(world: World, types: {i24}, prev: Archetype?): Archetype
	local ty = hash(types)

	local id = world.nextArchetypeId + 1
	world.nextArchetypeId = id

	local length = #types
	local columns = table.create(length) :: {any}

	for index in types do
		columns[index] = {}
	end

	local archetype = {
		columns = columns;
		edges = {};
		entities = {};
		id = id;
		records = {};
		type = ty;
		types = types;
	}
	world.archetypeIndex[ty] = archetype
	world.archetypes[id] = archetype
	if length > 0 then
		createArchetypeRecords(world.componentIndex, archetype, prev)
	end

	return archetype
end

local World = {}
World.__index = World
function World.new()
	local self = setmetatable({
		archetypeIndex = {};
		archetypes = {};
		componentIndex = {};
		entityIndex = {
			dense = {},
			sparse = {}
		} :: EntityIndex;
		hooks = {
			[ON_ADD] = {};
		};
		nextArchetypeId = 0;
		nextComponentId = 0;
		nextEntityId = 0;
		ROOT_ARCHETYPE = (nil :: any) :: Archetype;
	}, World)
	return self
end

local FLAGS_PAIR = 0x8

local function addFlags(flags) 
    local typeFlags = 0x0
    if flags.isPair then
        typeFlags = bit32.bor(typeFlags, FLAGS_PAIR) -- HIGHEST bit in the ID.
    end
    if false then
        typeFlags = bit32.bor(typeFlags, 0x4) -- Set the second flag to true
    end
    if false then
        typeFlags = bit32.bor(typeFlags, 0x2) -- Set the third flag to true
    end
    if false then
        typeFlags = bit32.bor(typeFlags, 0x1) -- LAST BIT in the ID.
    end

    return typeFlags
end

local ECS_ID_FLAGS_MASK = 0x10

-- ECS_ENTITY_MASK               (0xFFFFFFFFull << 28)
local ECS_ENTITY_MASK = bit32.lshift(1, 24)

-- ECS_GENERATION_MASK           (0xFFFFull << 24)
local ECS_GENERATION_MASK = bit32.lshift(1, 16)

local function newId(source: number, target: number) 
    local e = source * 2^28 + target * ECS_ID_FLAGS_MASK
    return e
end

local function isPair(e: number) 
    return (e % 2^4) // FLAGS_PAIR ~= 0
end

function separate(entity: number)
    local _typeFlags = entity % 0x10
    entity //= ECS_ID_FLAGS_MASK
    return entity // ECS_ENTITY_MASK, entity % ECS_GENERATION_MASK, _typeFlags
end

-- HIGH 24 bits LOW 24 bits
local function ECS_GENERATION(e: i53)
    e //= 0x10
    return e % ECS_GENERATION_MASK
end

local function ECS_ID(e: i53) 
    e //= 0x10
    return e // ECS_ENTITY_MASK
end

local function ECS_GENERATION_INC(e: i53)
    local id, generation, flags = separate(e)    

    return newId(id, generation + 1) + flags
end

-- gets the high ID
local function ECS_PAIR_FIRST(entity: i53): i24
    entity //= 0x10
    local first = entity % ECS_ENTITY_MASK
    return first
end

-- gets the low ID
local ECS_PAIR_SECOND = ECS_ID

local function ECS_PAIR(source: number, target: number)
    local id = newId(ECS_PAIR_SECOND(target), ECS_PAIR_SECOND(source)) + addFlags({ isPair = true })
    return id
end

local function getAlive(entityIndex: EntityIndex, id: i53) 
    return entityIndex.dense[id]
end

local function ecs_get_source(entityIndex, e) 
    assert(isPair(e))
    return getAlive(entityIndex, ECS_PAIR_FIRST(e))
end
local function ecs_get_target(entityIndex, e) 
    assert(isPair(e))
    return getAlive(entityIndex, ECS_PAIR_SECOND(e))
end

local function nextEntityId(entityIndex, index: i24) 
	local id = newId(index, 0)
	entityIndex.sparse[id] = {
		dense = index
	} :: Record	
	entityIndex.dense[index] = id

	return id
end

function World.component(world: World)
	local componentId = world.nextComponentId + 1
	if componentId > HI_COMPONENT_ID then
		-- IDs are partitioned into ranges because component IDs are not nominal,
		-- so it needs to error when IDs intersect into the entity range.
		error("Too many components, consider using world:entity() instead to create components.")
	end
	world.nextComponentId = componentId
	return nextEntityId(world.entityIndex, componentId)
end

function World.entity(world: World)
	local entityId = world.nextEntityId + 1
	world.nextEntityId = entityId
	return nextEntityId(world.entityIndex, entityId + REST)
end

-- should reuse this logic in World.set instead of swap removing in transition archetype
local function destructColumns(columns, count, row) 
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

local function archetypeDelete(entityIndex, record: Record, entityId: i53, destruct: boolean) 
	local sparse, dense = entityIndex.sparse, entityIndex.dense
	local archetype = record.archetype
	local row = record.row
	local entities = archetype.entities
	local last = #entities

	local entityToMove = entities[last]

	if row ~= last then 
		dense[record.dense] = entityToMove
		sparse[entityToMove] = record
	end

	sparse[entityId] = nil
	dense[#dense] = nil

	entities[row], entities[last] = entities[last], nil

	local columns = archetype.columns

	if not destruct then 
		return
	end

	destructColumns(columns, last, row)
end

function World.delete(world: World, entityId: i53) 
	local entityIndex = world.entityIndex
	local record = entityIndex.sparse[entityId]
	if not record then 
		return
	end
	archetypeDelete(entityIndex, record, entityId, true)
end

export type World = typeof(World.new())

local function ensureArchetype(world: World, types, prev)
	if #types < 1 then
		return world.ROOT_ARCHETYPE
	end

	local ty = hash(types)
	local archetype = world.archetypeIndex[ty]
	if archetype then
		return archetype
	end

	return archetypeOf(world, types, prev)
end

local function findInsert(types: {i53}, toAdd: i53)
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

local function findArchetypeWith(world: World, node: Archetype, componentId: i53)
	local types = node.types
	-- Component IDs are added incrementally, so inserting and sorting
	-- them each time would be expensive. Instead this insertion sort can find the insertion
	-- point in the types array.
	local at = findInsert(types, componentId)
	if at == -1 then
		-- If it finds a duplicate, it just means it is the same archetype so it can return it
		-- directly instead of needing to hash types for a lookup to the archetype.
		return node
	end

	local destinationType = table.clone(node.types)
	table.insert(destinationType, at, componentId)
	return ensureArchetype(world, destinationType, node)
end

local function ensureEdge(archetype: Archetype, componentId: i53)
	local edges = archetype.edges
	local edge = edges[componentId]
	if not edge then
		edge = {} :: any
		edges[componentId] = edge
	end
	return edge
end

local function archetypeTraverseAdd(world: World, componentId: i53, from: Archetype): Archetype
	if not from then
		-- If there was no source archetype then it should return the ROOT_ARCHETYPE
		local ROOT_ARCHETYPE = world.ROOT_ARCHETYPE
		if not ROOT_ARCHETYPE then
			ROOT_ARCHETYPE = archetypeOf(world, {}, nil)
			world.ROOT_ARCHETYPE = ROOT_ARCHETYPE :: never
		end
		from = ROOT_ARCHETYPE
	end

	local edge = ensureEdge(from, componentId)
	local add = edge.add
	if not add then
		-- Save an edge using the component ID to the archetype to allow
		-- faster traversals to adjacent archetypes.
		add = findArchetypeWith(world, from, componentId)
		edge.add = add :: never
	end

	return add
end

function World.add(world: World, entityId: i53, componentId: i53) 
	local entityIndex = world.entityIndex
	local record = entityIndex.sparse[entityId]
	local from = record.archetype
	local to = archetypeTraverseAdd(world, componentId, from)
	if from and not (from == world.ROOT_ARCHETYPE) then
		moveEntity(entityIndex, entityId, record, to)
	else
		if #to.types > 0 then
			newEntity(entityId, record, to)
		end
	end
end

-- Symmetric like `World.add` but idempotent
function World.set(world: World, entityId: i53, componentId: i53, data: unknown)
	local record = world.entityIndex.sparse[entityId]
	local from = record.archetype
	local to = archetypeTraverseAdd(world, componentId, from)

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
		moveEntity(world.entityIndex, entityId, record, to)
	else
		if #to.types > 0 then
			-- When there is no previous archetype it should create the archetype
			newEntity(entityId, record, to)
		end
	end

	local archetypeRecord = to.records[componentId]
	to.columns[archetypeRecord][record.row] = data
end

local function archetypeTraverseRemove(world: World, componentId: i53, from: Archetype): Archetype
	local edge = ensureEdge(from, componentId)

	local remove = edge.remove
	if not remove then
		local to = table.clone(from.types)
		local at = table.find(to, componentId)
		if not at then 
			return from
		end
		table.remove(to, at)
		remove = ensureArchetype(world, to, from)
		edge.remove = remove :: never
	end

	return remove
end

function World.remove(world: World, entityId: i53, componentId: i53)
	local entityIndex = world.entityIndex
	local record = entityIndex.sparse[entityId]
	local sourceArchetype = record.archetype
	local destinationArchetype = archetypeTraverseRemove(world, componentId, sourceArchetype)

	if sourceArchetype and not (sourceArchetype == destinationArchetype) then
		moveEntity(entityIndex, entityId, record, destinationArchetype)
	end
end

-- Keeping the function as small as possible to enable inlining
local function get(record: Record, componentId: i24)
	local archetype = record.archetype
	local archetypeRecord = archetype.records[componentId]

	if not archetypeRecord then
		return nil
	end

	return archetype.columns[archetypeRecord][record.row]
end

function World.get(world: World, entityId: i53, a: i53, b: i53?, c: i53?, d: i53?, e: i53?)
	local id = entityId
	local record = world.entityIndex.sparse[id]
	if not record then
		return nil
	end

	local va = get(record, a)

	if b == nil then
		return va
	elseif c == nil then
		return va, get(record, b)
	elseif d == nil then
		return va, get(record, b), get(record, c)
	elseif e == nil then
		return va, get(record, b), get(record, c), get(record, d)
	else
		error("args exceeded")
	end
end

-- the less creation the better
local function actualNoOperation() end
local function noop(_self: Query, ...: i53): () -> (number, ...any)
	return actualNoOperation :: any
end

local EmptyQuery = {
	__iter = noop;
	without = noop;
}
EmptyQuery.__index = EmptyQuery
setmetatable(EmptyQuery, EmptyQuery)

export type Query = typeof(EmptyQuery)

function World.query(world: World, ...: i53): Query
	-- breaking?
	if (...) == nil then
		error("Missing components")
	end

	local compatibleArchetypes = {}
	local length = 0

	local components = {...}
	local archetypes = world.archetypes
	local queryLength = #components

	local firstArchetypeMap
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

	for id in firstArchetypeMap.sparse do
		local archetype = archetypes[id]
		local archetypeRecords = archetype.records
		local indices = {}
		local skip = false

		for i, componentId in components do
			local index = archetypeRecords[componentId]
			if not index then
				skip = true
				break
			end
			indices[i] = index
		end

		if skip then
			continue
		end

		length += 1
		compatibleArchetypes[length] = {archetype, indices}
	end

	local lastArchetype, compatibleArchetype = next(compatibleArchetypes)
	if not lastArchetype then
		return EmptyQuery
	end

	local preparedQuery = {}
	preparedQuery.__index = preparedQuery

	function preparedQuery:without(...)
		local withoutComponents = {...}
		for i = #compatibleArchetypes, 1, -1 do
			local archetype = compatibleArchetypes[i][1]
			local records = archetype.records
			local shouldRemove = false

			for _, componentId in withoutComponents do
				if records[componentId] then
					shouldRemove = true
					break
				end
			end

			if shouldRemove then
				table.remove(compatibleArchetypes, i)
			end
		end

		lastArchetype, compatibleArchetype = next(compatibleArchetypes)
		if not lastArchetype then
			return EmptyQuery
		end

		return self
	end

	local lastRow
	local queryOutput = {}

	function preparedQuery:__iter()
		return function()
			local archetype = compatibleArchetype[1]
			local row = next(archetype.entities, lastRow)
			while row == nil do
				lastArchetype, compatibleArchetype = next(compatibleArchetypes, lastArchetype)
				if lastArchetype == nil then
					return
				end
				archetype = compatibleArchetype[1]
				row = next(archetype.entities, row)
			end
			lastRow = row

			local entityId = archetype.entities[row :: number]
			local columns = archetype.columns
			local tr = compatibleArchetype[2]

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

			for i in components do
				queryOutput[i] = columns[tr[i]][row]
			end

			return entityId, unpack(queryOutput, 1, queryLength)
		end
	end

	return setmetatable({}, preparedQuery) :: any
end

function World.__iter(world: World): () -> (number?, unknown?)
	local dense = world.entityIndex.dense
	local sparse = world.entityIndex.sparse
	local last

	return function() 
		local lastEntity, entityId = next(dense, last)
		if not lastEntity then 
			return
		end
		last = lastEntity

		local record = sparse[entityId]
		local archetype = record.archetype
		if not archetype then 
			-- Returns only the entity id as an entity without data should not return
			-- data and allow the user to get an error if they don't handle the case.
			return entityId
		end

		local row = record.row
		local types = archetype.types
		local columns = archetype.columns
		local entityData = {}
		for i, column in columns do
			-- We use types because the key should be the component ID not the column index
			entityData[types[i]] = column[row]
		end
		
		return entityId, entityData
	end
end

return table.freeze({
	World = World;
	ON_ADD = ON_ADD;
	ON_REMOVE = ON_REMOVE;
	ON_SET = ON_SET;
	ECS_ID = ECS_ID,
	IS_PAIR = isPair,
	ECS_PAIR = ECS_PAIR,
	ECS_GENERATION = ECS_GENERATION,
	ECS_GENERATION_INC = ECS_GENERATION_INC,
	getAlive = getAlive,
	ecs_get_target = ecs_get_target,
	ecs_get_source = ecs_get_source
})
