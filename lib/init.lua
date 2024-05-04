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
}

type EntityIndex = {[i24]: Record}
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

	-- Move the entity from the source to the destination archetype.
	local atSourceRow = sourceEntities[sourceRow]
	destinationEntities[destinationRow] = atSourceRow
	entityIndex[atSourceRow].row = destinationRow

	-- Because we have swapped columns we now have to update the records
	-- corresponding to the entities' rows that were swapped.
	local movedAway = #sourceEntities
	if sourceRow ~= movedAway then
		local atMovedAway = sourceEntities[movedAway]
		sourceEntities[sourceRow] = atMovedAway
		entityIndex[atMovedAway].row = sourceRow
	end

	sourceEntities[movedAway] = nil
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

local function createArchetypeRecords(componentIndex: ComponentIndex, to: Archetype, from: Archetype?)
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
		id = id;
		types = types;
		type = ty;
		columns = columns;
		entities = {};
		edges = {};
		records = {};
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
		entityIndex = {};
		componentIndex = {};
		archetypes = {};
		archetypeIndex = {};
		ROOT_ARCHETYPE = (nil :: any) :: Archetype;
		nextEntityId = 0;
		nextComponentId = 0;
		nextArchetypeId = 0;
		hooks = {
			[ON_ADD] = {};
		};
	}, World)
	return self
end

local function emit(world, eventDescription)
	local event = eventDescription.event

	table.insert(world.hooks[event], {
		ids = eventDescription.ids;
		archetype = eventDescription.archetype;
		otherArchetype = eventDescription.otherArchetype;
		offset = eventDescription.offset;
	})
end

local function onNotifyAdd(world, archetype, otherArchetype, row: number, added: Ty)
	if #added > 0 then
		emit(world, {
			event = ON_ADD;
			ids = added;
			archetype = archetype;
			otherArchetype = otherArchetype;
			offset = row;
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

local function ensureRecord(entityIndex, entityId: i53): Record
	local id = entityId
	local record = entityIndex[id]

	if not record then
		record = {}
		entityIndex[id] = record
	end

	return record :: Record
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
			onNotifyAdd(world, to, from, record.row, {componentId})
		end
	end

	local archetypeRecord = to.records[componentId]
	to.columns[archetypeRecord][record.row] = data
end

local function archetypeTraverseRemove(world: World, componentId: i53, archetype: Archetype?): Archetype
	local from = (archetype or world.ROOT_ARCHETYPE) :: Archetype
	local edge = ensureEdge(from, componentId)

	local remove = edge.remove
	if not remove then
		local to = table.clone(from.types)
		table.remove(to, table.find(to, componentId))
		remove = ensureArchetype(world, to, from)
		edge.remove = remove :: never
	end

	return remove
end

function World.remove(world: World, entityId: i53, componentId: i53)
	local entityIndex = world.entityIndex
	local record = ensureRecord(entityIndex, entityId)
	local sourceArchetype = record.archetype
	local destinationArchetype = archetypeTraverseRemove(world, componentId, sourceArchetype)

	if sourceArchetype and not (sourceArchetype == destinationArchetype) then
		moveEntity(entityIndex, entityId, record, destinationArchetype)
	end
end

-- Keeping the function as small as possible to enable inlining
local function get(_componentIndex: {[i24]: ArchetypeMap}, record: Record, componentId: i24)
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

local function noop(_self: Query, ...: i53): () -> (number, ...any)
	return function() end :: any
end

local EmptyQuery = {
	__iter = noop;
	without = noop;
}
EmptyQuery.__index = EmptyQuery
setmetatable(EmptyQuery, EmptyQuery)

export type Query = typeof(EmptyQuery)

function World.query(world: World, ...: i53): Query
	local compatibleArchetypes = {}
	local length = 0

	local components = {...}
	local archetypes = world.archetypes
	local queryLength = #components

	if queryLength == 0 then
		error("Missing components")
	end

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
			indices[i] = archetypeRecords[componentId]
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
		for index = #compatibleArchetypes, 1, -1 do
			local archetype = compatibleArchetypes[index][1]
			local records = archetype.records
			local shouldRemove = false
			for _, componentId in withoutComponents do
				if records[componentId] then
					shouldRemove = true
					break
				end
			end
			if shouldRemove then
				table.remove(compatibleArchetypes, index)
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
			local entities = archetype.entities
			local row = next(entities, lastRow)
			while row == nil do
				lastArchetype, compatibleArchetype = next(compatibleArchetypes, lastArchetype)
				if lastArchetype == nil then
					return
				end
				archetype = compatibleArchetype[1]
				entities = archetype.entities
				row = next(entities, row)
			end
			lastRow = row

			local entityId = entities[row :: number]
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

			for index in components do
				queryOutput[index] = tr[index][row]
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
	local nextEntityId = world.nextEntityId + 1
	world.nextEntityId = nextEntityId
	return nextEntityId + REST
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
	local componentIds = {...}
	local hooks = world.hooks

	return {
		event = function(event)
			local hook = hooks[event]
			hooks[event] = nil

			local last, change
			return function()
				last, change = next(hook, last)
				if not last then
					return
				end

				local matched = false
				local ids = change.ids

				while not matched do
					local skip = false
					for _, id in ids do
						if not table.find(componentIds, id) then
							skip = true
							break
						end
					end

					if skip then
						last, change = next(hook, last)
						ids = change.ids
						continue
					end

					matched = true
				end

				local queryOutput = {}
				local length = 0

				local row = change.offset
				local archetype = change.archetype
				local columns = archetype.columns
				local archetypeRecords = archetype.records
				for _, id in componentIds do
					local value = columns[archetypeRecords[id]][row]
					if value == nil then
						continue
					end

					length += 1
					queryOutput[length] = value
				end

				return archetype.entities[row], unpack(queryOutput, 1, length)
			end
		end;
	}
end

return table.freeze({
	World = World;
	ON_ADD = ON_ADD;
	ON_REMOVE = ON_REMOVE;
	ON_SET = ON_SET;
})
