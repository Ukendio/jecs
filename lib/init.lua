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
	destinationArchetype: Archetype,
	destinationRow: i24,
	sourceArchetype: Archetype,
	sourceRow: i24
)
	local columns = sourceArchetype.columns
	local sourceEntities = sourceArchetype.entities
	local destinationEntities = destinationArchetype.entities
	local destinationColumns = destinationArchetype.columns

	for componentId, column in columns do
		local targetColumn = destinationColumns[componentId]
		if targetColumn then 
			targetColumn[destinationRow] = column[sourceRow]
		end
		column[sourceRow] = column[#column]
		column[#column] = nil
	end

	destinationEntities[destinationRow] = sourceEntities[sourceRow] 
	local moveAway = #sourceEntities
	sourceEntities[sourceRow] = sourceEntities[moveAway]
	sourceEntities[moveAway] = nil
	entityIndex[destinationEntities[destinationRow]].row = sourceRow
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
	createArchetypeRecords(world.componentIndex, archetype, prev)

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
        nextId = 0,
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


type World = typeof(World.new())

local function ensureArchetype(world: World, types, prev)
	if #types < 1 then
		
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
	local at = findInsert(types, componentId)
	if at == -1 then
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
		if not world.ROOT_ARCHETYPE then 
            local ROOT_ARCHETYPE = archetypeOf(world, {}, nil)
            world.ROOT_ARCHETYPE = ROOT_ARCHETYPE
        end
		from = world.ROOT_ARCHETYPE
	end
	local edge = ensureEdge(from, componentId)

	if not edge.add then
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
	local sourceArchetype = record.archetype
	local destinationArchetype = archetypeTraverseAdd(world, componentId, sourceArchetype)

	if sourceArchetype and not (sourceArchetype == destinationArchetype) then
		moveEntity(world.entityIndex, entityId, record, destinationArchetype)
	else
		-- if it has any components, then it wont be the root archetype
		if #destinationArchetype.types > 0 then
			newEntity(entityId, record, destinationArchetype)
			onNotifyAdd(world, destinationArchetype, sourceArchetype, record.row, { componentId })
		end
	end
	local archetypeRecord = destinationArchetype.records[componentId]
	destinationArchetype.columns[archetypeRecord][record.row] = data
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

local function get(componentIndex: { [i24]: ArchetypeMap }, record: Record, componentId: i24)
	local archetype = record.archetype
	local archetypeRecord = componentIndex[componentId].sparse[archetype.id]

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



local function noop(): any
	return function() 
	end
end

local function getSmallestMap(componentIndex, components) 
	local s: any

	for i, componentId in components do 
		local map = componentIndex[componentId]
		if s == nil or map.size < s.size then 
			s = map	
		end
	end
	
	return s.sparse
end

local PreparedQuery = {}
PreparedQuery.__index = PreparedQuery

function PreparedQuery:__iter() 
	local compatibleArchetypes = self.compatibleArchetypes
	local queryLength = self.queryLength
	local components = self.components

	local lastArchetype, compatibleArchetype = next(compatibleArchetypes)
	if not compatibleArchetype then 
		return noop()
	end
	
	local lastRow 
	 
	return function() 
        local archetype = compatibleArchetype.archetype
        local indices = compatibleArchetype.indices
		local row = next(archetype.entities, lastRow)
		while row == nil do 
			lastArchetype, compatibleArchetype = next(compatibleArchetypes, lastArchetype)
			if lastArchetype == nil then 
				return 
			end
            archetype = compatibleArchetype.archetype
			row = next(archetype.entities, row)
		end
		lastRow = row
		
		local entityId = archetype.entities[row :: number]

		if queryLength == 1 then 
			return entityId, indices[1][row]
		elseif queryLength == 2 then 
			return entityId, indices[1][row], indices[2][row]
		elseif queryLength == 3 then 
			return entityId, 
				indices[1][row],
				indices[2][row], 
				indices[3][row]
		elseif queryLength == 4 then 
			return entityId, 
                indices[1][row],
                indices[2][row], 
                indices[3][row],
                indices[4][row]
		elseif queryLength == 5 then 
			return entityId, 
                indices[1][row],
                indices[2][row], 
                indices[3][row],
                indices[4][row]
		elseif queryLength == 6 then 
			return entityId, 
                indices[1][row],
                indices[2][row], 
                indices[3][row],
                indices[4][row],
                indices[5][row],
                indices[6][row]
        elseif queryLength == 7 then 
			return entityId, 
                indices[1][row],
                indices[2][row], 
                indices[3][row],
                indices[4][row],
                indices[5][row],
                indices[6][row],
                indices[7][row]

		elseif queryLength == 8 then 
			return entityId, 
                indices[1][row],
                indices[2][row], 
                indices[3][row],
                indices[4][row],
                indices[5][row],
                indices[6][row],
                indices[7][row],
                indices[8][row]
		end

		local queryOutput = {}
		for i, componentId in components do 
			queryOutput[i] = indices[i][row]
		end

		return entityId, unpack(queryOutput, 1, queryLength)
	end
end

function World.query(world: World, ...: i53)
	local compatibleArchetypes = {}
	local components = { ... }
	local archetypes = world.archetypes
	local queryLength = #components
	local firstArchetypeMap = getSmallestMap(world.componentIndex, components)

	if not firstArchetypeMap then 
		return noop()
	end

	for id in firstArchetypeMap do
		local archetype = archetypes[id]
        local columns = archetype.columns
		local archetypeRecords = archetype.records
        local indices = {}
		local skip = false
		
		for i, componentId in components do 
			local index = archetypeRecords[componentId]
			if not index then 
				skip = true
				break
			end
			indices[i] = columns[index]
		end

		if skip then 
			continue
		end

		table.insert(compatibleArchetypes, {
			archetype = archetype,
			indices = indices
		})
	end
	
	return setmetatable({
		queryLength = queryLength,
		compatibleArchetypes = compatibleArchetypes,
		components = components 
	}, PreparedQuery)
end

function World.component(world: World) 
	local id = world.nextId + 1
	if id > HI_COMPONENT_ID then 
		error("Too many components")	
	end
	return id
end

function World.entity(world: World)
    world.nextId += 1
	return world.nextId + REST
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