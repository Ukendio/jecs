--!optimize 2
--!native
--!strict
--draft 4

type i53 = number
type i24 = number

type Ty = { i53 }
type ArchetypeId = number

type Column = { any }

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
	entities: { number },
	columns: { Column },
	records: {},
}

type Record = {
	archetype: Archetype,
	row: number,
}

type EntityIndex = { [i24]: Record }
type ComponentIndex = { [i24]: ArchetypeMap}

type ArchetypeRecord = number
type ArchetypeMap = { sparse: { [ArchetypeId]: ArchetypeRecord } , size: number }
type Archetypes = { [ArchetypeId]: Archetype }
	
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

	-- Move the entity from the source to the destination archetype.
	destinationEntities[destinationRow] = sourceEntities[sourceRow]
	entityIndex[sourceEntities[sourceRow]].row = destinationRow

	-- Because we have swapped columns we now have to update the records
	-- corresponding to the entities' rows that were swapped.
	local movedAway = #sourceEntities
	if sourceRow ~= movedAway then 
		sourceEntities[sourceRow] = sourceEntities[movedAway]
		entityIndex[sourceEntities[movedAway]].row = sourceRow
	end
	
	sourceEntities[movedAway] = nil
end

local function archetypeAppend(entity: i53, archetype: Archetype): i24
	local entities = archetype.entities
	table.insert(entities, entity)
	return #entities
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

local function createArchetypeRecords(componentIndex: ComponentIndex, to: Archetype, from: Archetype?)
	local destinationCount = #to.types
	local destinationIds = to.types

	for i = 1, destinationCount do
		local destinationId = destinationIds[i]

		if not componentIndex[destinationId] then
			componentIndex[destinationId] = { size = 0, sparse = {} }
		end

		local archetypesMap = componentIndex[destinationId]
		archetypesMap.sparse[to.id] = i
		to.records[destinationId] = i
	end
end

local function archetypeOf(world: World, types: { i24 }, prev: Archetype?): Archetype
	local ty = hash(types)

	world.nextArchetypeId = (world.nextArchetypeId::number)+ 1
    local id = world.nextArchetypeId

	local columns = {} :: { any }

	for _ in types do
		table.insert(columns, {})
	end

	local archetype = {
		id = id,
		types = types,
		type = ty,
		columns = columns,
		entities = {},
		edges = {},
		records = {},
	}
	world.archetypeIndex[ty] = archetype
	world.archetypes[id] = archetype
	if #types > 0 then 
		createArchetypeRecords(world.componentIndex, archetype, prev)
	end

	return archetype
end

local World = {}
World.__index = World
function World.new() 
	local self = setmetatable({
		entityIndex = {},
		componentIndex = {},
		archetypes = {},
		archetypeIndex = {},
        ROOT_ARCHETYPE = (nil :: any) :: Archetype,
        nextEntityId = 0,
		nextComponentId = 0,
        nextArchetypeId = 0,
		hooks = {
			[ON_ADD] = {}
		}
	}, World)
    return self
end

local function emit(world, eventDescription) 
	local event = eventDescription.event

	table.insert(world.hooks[event], {
		ids = eventDescription.ids,
		archetype = eventDescription.archetype,
		otherArchetype = eventDescription.otherArchetype,
		offset = eventDescription.offset
	})
end

local function onNotifyAdd(world, archetype, otherArchetype, row: number, added: Ty) 
	if #added > 0 then 
		emit(world, {
			event = ON_ADD,
			ids = added,
			archetype = archetype,
			otherArchetype = otherArchetype,
			offset = row,
		})
	end
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

local function findInsert(types: { i53 }, toAdd: i53)
	local count = #types
	for i = 1, count do
		local id = types[i]
		if id == toAdd then
			return -1
		end
		if id > toAdd then
			return i
		end
	end
	return count + 1
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
	if not archetype.edges[componentId] then
		archetype.edges[componentId] = {} :: any
	end
	return archetype.edges[componentId]
end

local function archetypeTraverseAdd(world: World, componentId: i53, from: Archetype): Archetype
	if not from then 
		-- If there was no source archetype then it should return the ROOT_ARCHETYPE
		if not world.ROOT_ARCHETYPE then 
            local ROOT_ARCHETYPE = archetypeOf(world, {}, nil)
            world.ROOT_ARCHETYPE = ROOT_ARCHETYPE
        end
		from = world.ROOT_ARCHETYPE
	end
	local edge = ensureEdge(from, componentId)

	if not edge.add then
		-- Save an edge using the component ID to the archetype to allow 
		-- faster traversals to adjacent archetypes.
		edge.add = findArchetypeWith(world, from, componentId)
	end

	return edge.add
end

local function ensureRecord(entityIndex, entityId: i53): Record
	local id = entityId
	if not entityIndex[id] then
		entityIndex[id] = {}
	end
	return entityIndex[id] :: Record
end

function World.set(world: World, entityId: i53, componentId: i53, data: unknown) 
	local record = ensureRecord(world.entityIndex, entityId)
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
			onNotifyAdd(world, to, from, record.row, { componentId })
		end
	end

	local archetypeRecord = to.records[componentId]
	to.columns[archetypeRecord][record.row] = data
end

local function archetypeTraverseRemove(world: World, componentId: i53, archetype: Archetype?): Archetype
	local from = (archetype or world.ROOT_ARCHETYPE) :: Archetype
	local edge = ensureEdge(from, componentId)


	if not edge.remove then
		local to = table.clone(from.types) 
		table.remove(to, table.find(to, componentId))
		edge.remove = ensureArchetype(world, to, from)
	end

	return edge.remove
end

function World.remove(world: World, entityId: i53, componentId: i53) 
	local record = ensureRecord(world.entityIndex, entityId)
	local sourceArchetype = record.archetype
	local destinationArchetype = archetypeTraverseRemove(world, componentId, sourceArchetype)

	if sourceArchetype and not (sourceArchetype == destinationArchetype) then 
		moveEntity(world.entityIndex, entityId, record, destinationArchetype)
	end
end

-- Keeping the function as small as possible to enable inlining
local function get(componentIndex: { [i24]: ArchetypeMap }, record: Record, componentId: i24)
	local archetype = record.archetype
	local archetypeRecord = archetype.records[componentId]

	if not archetypeRecord then
		return nil
	end

	return archetype.columns[archetypeRecord][record.row]
end

function World.get(world: World, entityId: i53, a: i53, b: i53?, c: i53?, d: i53?, e: i53?)
	local id = entityId
    local componentIndex = world.componentIndex
	local record = world.entityIndex[id]
	if not record then
		return nil
	end

	local va = get(componentIndex, record, a)

	if b == nil then
		return va
	elseif c == nil then
		return va, get(componentIndex, record, b)
	elseif d == nil then
		return va, get(componentIndex, record, b), get(componentIndex, record, c)
	elseif e == nil then
		return va, get(componentIndex, record, b), get(componentIndex, record, c), get(componentIndex, record, d)
	else
		error("args exceeded")
	end
end

local function noop(self: Query, ...: i53): () -> (number, ...any)
	return function()
	end :: any
end

local EmptyQuery = {
	__iter = noop,
	without = noop
}
EmptyQuery.__index = EmptyQuery
setmetatable(EmptyQuery, EmptyQuery)

export type Query = typeof(EmptyQuery)

function World.query(world: World, ...: i53): Query
	local compatibleArchetypes = {}
	local components = { ... }
	local archetypes = world.archetypes
	local queryLength = #components

	if queryLength == 0 then 
		error("Missing components")
	end

	local firstArchetypeMap
	local componentIndex = world.componentIndex

	for i, componentId in components do 
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
			indices[i] = archetypeRecords[componentId]
		end

		if skip then 
			continue
		end
		table.insert(compatibleArchetypes, { archetype, indices })
	end

	local lastArchetype, compatibleArchetype = next(compatibleArchetypes)
	if not lastArchetype then 
		return EmptyQuery
	end
	
	local preparedQuery = {}
	preparedQuery.__index = preparedQuery

	function preparedQuery:without(...) 
		local components = { ... }
		for i = #compatibleArchetypes, 1, -1 do 
			local archetype = compatibleArchetypes[i][1]
			local shouldRemove = false
			for _, componentId in components do 
				if archetype.records[componentId] then 
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
				return entityId, 
					columns[tr[1]][row],
					columns[tr[2]][row],
					columns[tr[3]][row]
			elseif queryLength == 4 then 
				return entityId, 
					columns[tr[1]][row],
					columns[tr[2]][row],
					columns[tr[3]][row],
					columns[tr[4]][row]
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
				queryOutput[i] = tr[i][row]
			end

			return entityId, unpack(queryOutput, 1, queryLength)
		end
	end

	return setmetatable({}, preparedQuery) :: any
end

function World.component(world: World) 
	local componentId = world.nextComponentId + 1	
	if componentId > HI_COMPONENT_ID then 
		-- IDs are partitioned into ranges because component IDs are not nominal, 
		-- so it needs to error when IDs intersect into the entity range.
		error("Too many components, consider using world:entity() instead to create components.")	
	end
	world.nextComponentId = componentId
	return componentId
end

function World.entity(world: World)
	world.nextEntityId += 1
	return world.nextEntityId + REST
end

function World.delete(world: World, entityId: i53) 
	local entityIndex = world.entityIndex
	local record = entityIndex[entityId]
	moveEntity(entityIndex, entityId, record, world.ROOT_ARCHETYPE)
	-- Since we just appended an entity to the ROOT_ARCHETYPE we have to remove it from
	-- the entities array and delete the record. We know there won't be the hole since
	-- we are always removing the last row.
	--world.ROOT_ARCHETYPE.entities[record.row] = nil
	--entityIndex[entityId] = nil
end

function World.observer(world: World, ...)
	local componentIds = { ... }
	
	return {
		event = function(event) 
			local hook = world.hooks[event]
			world.hooks[event] = nil

			local last, change
			return function() 
				last, change = next(hook, last)
				if not last then 
					return
				end

				local matched = false
				
				while not matched do 
					local skip = false
					for _, id in change.ids do 
						if not table.find(componentIds, id) then 
							skip = true
							break
						end
					end
					
					if skip then 
						last, change = next(hook, last)
						continue
					end

					matched = true
				end
				
				local queryOutput = {}
				local row = change.offset
				local archetype = change.archetype
				local columns = archetype.columns
				local archetypeRecords = archetype.records
				for _, id in componentIds do 
					table.insert(queryOutput, columns[archetypeRecords[id]][row])
				end

				return archetype.entities[row], unpack(queryOutput, 1, #queryOutput)
			end
		end
	}
end

return table.freeze({
	World = World,
	ON_ADD = ON_ADD,
	ON_REMOVE = ON_REMOVE,
	ON_SET = ON_SET
})
