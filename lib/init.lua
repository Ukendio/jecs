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
type ArchetypeMap = { [ArchetypeId]: ArchetypeRecord }
type Archetypes = { [ArchetypeId]: Archetype }

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
	if true then
		return table.concat(arr, "_")
	end
	local hashed = 5381
	for i = 1, #arr do
		hashed = ((bit32.lshift(hashed, 5)) + hashed) + arr[i]
	end
	return hashed
end

local function createArchetypeRecords(componentIndex: ComponentIndex, to: Archetype, from: Archetype?)
	local destinationCount = #to.types
	local destinationIds = to.types

	for i = 1, destinationCount do
		local destinationId = destinationIds[i]

		if not componentIndex[destinationId] then
			componentIndex[destinationId] = {}
		end
		componentIndex[destinationId][to.id] = i
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
        ROOT_ARCHETYPE = nil :: Archetype?,
        nextId = 0,
        nextArchetypeId = 0 
	}, World)
    self.ROOT_ARCHETYPE = archetypeOf(self, {}, nil)
    return self
end

type World = typeof(World.new())

local function ensureArchetype(world: World, types, prev)
	if #types < 1 then

		if not world.ROOT_ARCHETYPE then 
            local ROOT_ARCHETYPE = archetypeOf(world, {}, nil)
            world.ROOT_ARCHETYPE = ROOT_ARCHETYPE
            return ROOT_ARCHETYPE
        end
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

local function archetypeTraverseAdd(world: World, componentId: i53, archetype: Archetype?): Archetype
	local from = (archetype or world.ROOT_ARCHETYPE) :: Archetype
	local edge = ensureEdge(from, componentId)

	if not edge.add then
		edge.add = findArchetypeWith(world, from, componentId)
	end

	return edge.add
end

function World.ensureRecord(world: World, entityId: i53)
    local entityIndex = world.entityIndex
	local id = entityId
	if not entityIndex[id] then
		entityIndex[id] = {} :: Record
	end
	return entityIndex[id]
end

function World.set(world: World, entityId: i53, componentId: i53, data: unknown) 
	local record = world:ensureRecord(entityId)
	local sourceArchetype = record.archetype
	local destinationArchetype = archetypeTraverseAdd(world, componentId, sourceArchetype)

	if sourceArchetype and not (sourceArchetype == destinationArchetype) then
		moveEntity(world.entityIndex, entityId, record, destinationArchetype)
	else
		-- if it has any components, then it wont be the root archetype
		if #destinationArchetype.types > 0 then
			newEntity(entityId, record, destinationArchetype)
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
	local record = world:ensureRecord(entityId)
	local sourceArchetype = record.archetype
	local destinationArchetype = archetypeTraverseRemove(world, componentId, sourceArchetype)

	if sourceArchetype and not (sourceArchetype == destinationArchetype) then 
		moveEntity(world.entityIndex, entityId, record, destinationArchetype)
	end
end

local function get(componentIndex: { [i24]: ArchetypeMap }, record: Record, componentId: i24)
	local archetype = record.archetype
	local archetypeRecord = componentIndex[componentId][archetype.id]

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

function World.entity(world: World)
    world.nextId += 1
	return world.nextId
end

function World.archetypesWith(world: World, componentId: i53)
    local archetypes = world.archetypes
	local archetypeMap = world.componentIndex[componentId]
	local compatibleArchetypes = {}
	for id, archetypeRecord in archetypeMap do
		compatibleArchetypes[archetypes[id]] = true
	end
	return compatibleArchetypes
end

local function noop(): any
	return function() 
	end
end

function World.query(world: World, ...: i53): (() -> (number, ...any)) | () -> ()
	local compatibleArchetypes = {}
	local components = { ... }
	local archetypes = world.archetypes
	local queryLength = #components
	local a, b, c, d, e = ...
	local firstArchetypeMap = world.componentIndex[components[1]]
	if not firstArchetypeMap then 
		return noop()
	end

	if queryLength == 1 then 
		local function single() 
            local id = next(firstArchetypeMap)
            local archetype = archetypes[id :: number]
            local lastRow

            return function(): any
                local row, entity = next(archetype.entities, lastRow)
                while row == nil do 
                    id = next(firstArchetypeMap, id)
                    if id == nil then 
                        return
                    end
                    archetype = archetypes[id]
                    row = next(archetype.entities, row)
                end 
                lastRow = row

                return entity, archetype.columns[archetype.records[a]]
            end
        end

        return single() 
	elseif queryLength == 2 then 
		for id in firstArchetypeMap do
			local archetype = archetypes[id]
			if archetype.records[b] then
				table.insert(compatibleArchetypes, archetype)	
			end
		end

		local function double() 
			local lastArchetype, archetype = next(compatibleArchetypes)
			local lastRow
	
			return function()
				local row = next(archetype.entities, lastRow)
				while row == nil do 
					lastArchetype, archetype = next(compatibleArchetypes, lastArchetype)
					if lastArchetype == nil then 
						return
					end
					row = next(archetype.entities, row)
				end 
				lastRow = row
	
				local entity = archetype.entities[row::number]
				local columns = archetype.columns
				local archetypeRecords = archetype.records
				return entity, columns[archetypeRecords[a]], columns[archetypeRecords[b]]
			end
		end
		return double()
	end

	for id in firstArchetypeMap do
		local archetype = archetypes[id]
		local archetypeRecords = archetype.records
		local matched = true
		for _, componentId in components do 
			if not archetypeRecords[componentId] then 
				matched = false
				break
			end
		end
		if matched then 
			table.insert(compatibleArchetypes, archetype)	
		end
	end
	
	local lastArchetype, archetype = next(compatibleArchetypes)
	
	local lastRow 
	
	local function queryNext()
		local row = next(archetype.entities, lastRow)
		while row == nil do 
			lastArchetype, archetype = next(compatibleArchetypes, lastArchetype)
			if lastArchetype == nil then 
				return 
			end
			row = next(archetype.entities, row)
		end
		lastRow = row
		
		local columns = archetype.columns	
		local entityId = archetype.entities[row :: number]
		local archetypeRecords = archetype.records

		if queryLength == 3 then 
			return entityId, 
				columns[archetypeRecords[a]], 
				columns[archetypeRecords[b]], 
				columns[archetypeRecords[c]]
		elseif queryLength == 4 then 
			return entityId, 
				columns[archetypeRecords[a]], 
				columns[archetypeRecords[b]], 
				columns[archetypeRecords[c]], 
				columns[archetypeRecords[d]]
		elseif queryLength == 5 then 
			return entityId, 
				columns[archetypeRecords[a]], 
				columns[archetypeRecords[b]], 
				columns[archetypeRecords[c]], 
				columns[archetypeRecords[d]], 
				columns[archetypeRecords[e]]
		end

		local queryOutput = {}
		for i, componentId in components do 
			queryOutput[i] = columns[archetypeRecords[componentId]]
		end

		return entityId, unpack(queryOutput, 1, queryLength)
	end

	return function() 
		return queryNext() 
	end
	
end

return {
	World = World
} 