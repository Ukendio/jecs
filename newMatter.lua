--!optimize 2
--!native
--!strict

local None = {}

local function merge(one, two)
	local new = table.clone(one)

	for key, value in two do
		if value == None then
			new[key] = nil
		else
			new[key] = value
		end
	end

	return new
end

-- https://github.com/freddylist/llama/blob/master/src/List/toSet.lua
local function toSet(list)
	local set = {}

	for _, v in ipairs(list) do
		set[v] = true
	end

	return set
end

-- https://github.com/freddylist/llama/blob/master/src/Dictionary/values.lua
local function values(dictionary)
	local valuesList = {}

	local index = 1

	for _, value in pairs(dictionary) do
		valuesList[index] = value
		index = index + 1
	end

	return valuesList
end

local stack = {}

local function newStackFrame(node)
	return {
		node = node,
		accessedKeys = {},
	}
end

local function cleanup()
	local currentFrame = stack[#stack]

	for baseKey, state in pairs(currentFrame.node.system) do
		for key, value in pairs(state.storage) do
			if not currentFrame.accessedKeys[baseKey] or not currentFrame.accessedKeys[baseKey][key] then
				local cleanupCallback = state.cleanupCallback

				if cleanupCallback then
					local shouldAbortCleanup = cleanupCallback(value)

					if shouldAbortCleanup then
						continue
					end
				end

				state.storage[key] = nil
			end
		end
	end
end

local function start(node, fn)
	table.insert(stack, newStackFrame(node))
	fn()
	cleanup()
	table.remove(stack, #stack)
end

local function withinTopoContext()
	return #stack ~= 0
end

local function useFrameState()
	return stack[#stack].node.frame
end

local function useCurrentSystem()
	if #stack == 0 then
		return
	end

	return stack[#stack].node.currentSystem
end


--[=[
	@within Matter

	:::tip
	**Don't use this function directly in your systems.**

	This function is used for implementing your own topologically-aware functions. It should not be used in your
	systems directly. You should use this function to implement your own utilities, similar to `useEvent` and
	`useThrottle`.
	:::

	`useHookState` does one thing: it returns a table. An empty, pristine table. Here's the cool thing though:
	it always returns the *same* table, based on the script and line where *your function* (the function calling
	`useHookState`) was called.

	### Uniqueness

	If your function is called multiple times from the same line, perhaps within a loop, the default behavior of
	`useHookState` is to uniquely identify these by call count, and will return a unique table for each call.

	However, you can override this behavior: you can choose to key by any other value. This means that in addition to
	script and line number, the storage will also only return the same table if the unique value (otherwise known as the
	"discriminator") is the same.

	### Cleaning up
	As a second optional parameter, you can pass a function that is automatically invoked when your storage is about
	to be cleaned up. This happens when your function (and by extension, `useHookState`) ceases to be called again
	next frame (keyed by script, line number, and discriminator).

	Your cleanup callback is passed the storage table that's about to be cleaned up. You can then perform cleanup work,
	like disconnecting events.

	*Or*, you could return `true`, and abort cleaning up altogether. If you abort cleanup, your storage will stick
	around another frame (even if your function wasn't called again). This can be used when you know that the user will
	(or might) eventually call your function again, even if they didn't this frame. (For example, caching a value for
	a number of seconds).

	If cleanup is aborted, your cleanup function will continue to be called every frame, until you don't abort cleanup,
	or the user actually calls your function again.

	### Example: useThrottle

	This is the entire implementation of the built-in `useThrottle` function:

	```lua
	local function cleanup(storage)
		return os.clock() < storage.expiry
	end

	local function useThrottle(seconds, discriminator)
		local storage = useHookState(discriminator, cleanup)

		if storage.time == nil or os.clock() - storage.time >= seconds then
			storage.time = os.clock()
			storage.expiry = os.clock() + seconds
			return true
		end

		return false
	end
	```

	A lot of talk for something so simple, right?

	@param discriminator? any -- A unique value to additionally key by
	@param cleanupCallback (storage: {}) -> boolean? -- A function to run when the storage for this hook is cleaned up
]=]
local function useHookState(discriminator, cleanupCallback): {}
	local file, line = debug.info(3, "sl")
	local fn = debug.info(2, "f")

	local baseKey = string.format("%s:%s:%d", tostring(fn), file, line)

	local currentFrame = stack[#stack]

	if currentFrame == nil then
		error("Attempt to access topologically-aware storage outside of a Loop-system context.", 3)
	end

	if not currentFrame.accessedKeys[baseKey] then
		currentFrame.accessedKeys[baseKey] = {}
	end

	local accessedKeys = currentFrame.accessedKeys[baseKey]

	local key = #accessedKeys

	if discriminator ~= nil then
		if type(discriminator) == "number" then
			discriminator = tostring(discriminator)
		end

		key = discriminator
	end

	accessedKeys[key] = true

	if not currentFrame.node.system[baseKey] then
		currentFrame.node.system[baseKey] = {
			storage = {},
			cleanupCallback = cleanupCallback,
		}
	end

	local storage = currentFrame.node.system[baseKey].storage

	if not storage[key] then
		storage[key] = {}
	end

	return storage[key]
end

local topoRuntime = {
	start = start,
	useHookState = useHookState,
	useFrameState = useFrameState,
	useCurrentSystem = useCurrentSystem,
	withinTopoContext = withinTopoContext,
}


--[=[
	@class Component

	A component is a named piece of data that exists on an entity.
	Components are created and removed in the [World](/api/World).

	In the docs, the terms "Component" and "ComponentInstance" are used:
	- **"Component"** refers to the base class of a specific type of component you've created.
		This is what [`Matter.component`](/api/Matter#component) returns.
	- **"Component Instance"** refers to an actual piece of data that can exist on an entity.
		The metatable of a component instance table is its respective Component table.

	Component instances are *plain-old data*: they do not contain behaviors or methods.

	Since component instances are immutable, one helper function exists on all component instances, `patch`,
	which allows reusing data from an existing component instance to make up for the ergonomic loss of mutations.
]=]

--[=[
	@within Component
	@type ComponentInstance {}

	The `ComponentInstance` type refers to an actual piece of data that can exist on an entity.
	The metatable of the component instance table is set to its particular Component table.

	A component instance can be created by calling the Component table:

	```lua
	-- Component:
	local MyComponent = Matter.component("My component")

	-- component instance:
	local myComponentInstance = MyComponent({
		some = "data"
	})

	print(getmetatable(myComponentInstance) == MyComponent) --> true
	```
]=]

-- This is a special value we set inside the component's metatable that will allow us to detect when
-- a Component is accidentally inserted as a Component Instance.
-- It should not be accessible through indexing into a component instance directly.
local DIAGNOSTIC_COMPONENT_MARKER = {}

local nextId = 0
local function newComponent(name, defaultData)
	name = name or debug.info(2, "s") .. "@" .. debug.info(2, "l")
	assert(
		defaultData == nil or type(defaultData) == "table",
		"if component default data is specified, it must be a table"
	)

	local component = {}
	component.__index = component

	function component.new(data)
		data = data or {}

		if defaultData then
			data = merge(defaultData, data)
		end

		return table.freeze(setmetatable(data, component))
	end

	--[=[
	@within Component

	```lua
	for id, target in world:query(Target) do
		if shouldChangeTarget(target) then
			world:insert(id, target:patch({ -- modify the existing component
				currentTarget = getNewTarget()
			}))
		end
	end
	```

	A utility function used to immutably modify an existing component instance. Key/value pairs from the passed table
	will override those of the existing component instance.

	As all components are immutable and frozen, it is not possible to modify the existing component directly.

	You can use the `Matter.None` constant to remove a value from the component instance:

	```lua
	target:patch({
		currentTarget = Matter.None -- sets currentTarget to nil
	})
	```

	@param partialNewData {} -- The table to be merged with the existing component data.
	@return ComponentInstance -- A copy of the component instance with values from `partialNewData` overriding existing values.
	]=]
	function component:patch(partialNewData)
		local patch = getmetatable(self).new(merge(self, partialNewData))
		return patch
	end

	nextId += 1
	local id = nextId

	setmetatable(component, {
		__call = function(_, ...)
			return component.new(...)
		end,
		__tostring = function()
			return name
		end,
		__len = function()
			return id
		end,
		[DIAGNOSTIC_COMPONENT_MARKER] = true,
	})

	return component
end

local function assertValidType(value, position)
	if typeof(value) ~= "table" then
		error(string.format("Component #%d is invalid: not a table", position), 3)
	end

	local metatable = getmetatable(value)

	if metatable == nil then
		error(string.format("Component #%d is invalid: has no metatable", position), 3)
	end
end

local function assertValidComponent(value, position)
	assertValidType(value, position)

	local metatable = getmetatable(value)

	if getmetatable(metatable) ~= nil and getmetatable(metatable)[DIAGNOSTIC_COMPONENT_MARKER] then
		error(
			string.format(
				"Component #%d is invalid: Component Instance %s was passed instead of the Component itself!",
				position,
				tostring(metatable)
			),
			3
		)
	end
end

local function assertValidComponentInstance(value, position)
	assertValidType(value, position)

	if getmetatable(value)[DIAGNOSTIC_COMPONENT_MARKER] ~= nil then
		error(
			string.format(
				"Component #%d is invalid: passed a Component instead of a Component instance; "
					.. "did you forget to call it as a function?",
				position
			),
			3
		)
	end
end

local ERROR_NO_ENTITY = "Entity doesn't exist, use world:contains to check if needed"
local ERROR_DUPLICATE_ENTITY =
	"The world already contains an entity with ID %d. Use World:replace instead if this is intentional."
local ERROR_NO_COMPONENTS = "Missing components"

type i53 = number
type i24 = number

type Component = { [any]: any }
type ComponentInstance = Component

type Ty = { i53 }
type ArchetypeId = number

type Column = { any }

type Archetype = {
	-- Unique identifier of this archetype
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
type ComponentIndex = { [i24]: ArchetypeMap }

type ArchetypeRecord = number
type ArchetypeMap = { sparse: { [ArchetypeId]: ArchetypeRecord }, size: number }
type Archetypes = { [ArchetypeId]: Archetype }

local function transitionArchetype(
	entityIndex: EntityIndex,
	to: Archetype,
	destinationRow: i24,
	from: Archetype,
	sourceRow: i24
)
	-- local columns = sourceArchetype.columns
	-- local sourceEntities = sourceArchetype.entities
	-- local destinationEntities = destinationArchetype.entities
	-- local destinationColumns = destinationArchetype.columns

	local columns = from.columns
	local sourceEntities = from.entities
	local destinationEntities = to.entities
	local destinationColumns = to.columns
	local tr = to.records
	local types = from.types

	for componentId, column in columns do
		local targetColumn = destinationColumns[tr[types[componentId]]]
		if targetColumn then
			targetColumn[destinationRow] = column[sourceRow]
		end

		if sourceRow ~= #column then
			column[sourceRow] = column[#column]
			column[#column] = nil
		end
	end

	destinationEntities[destinationRow] = sourceEntities[sourceRow]
	entityIndex[sourceEntities[sourceRow]].row = destinationRow

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

local function createArchetypeRecords(componentIndex: ComponentIndex, to: Archetype)
	local destinationCount = #to.types
	local destinationIds = to.types

	for i = 1, destinationCount do
		local destinationId = destinationIds[i]

		if not componentIndex[destinationId] then
			componentIndex[destinationId] = { sparse = {}, size = 0 }
		end
		componentIndex[destinationId].sparse[to.id] = i
		to.records[destinationId] = i
	end
end

local function archetypeOf(world: World, types: { i24 }, prev: Archetype?): Archetype
	local ty = hash(types)

	world.nextArchetypeId = (world.nextArchetypeId :: number) + 1
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
		nextId = 0,
		nextArchetypeId = 0,
		_size = 0,
		_changedStorage = {},
	}, World)

	self.ROOT_ARCHETYPE = archetypeOf(self, {}, nil)
	return self
end

type World = typeof(World.new())

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

local function componentAdd(world: World, entityId: i53, componentInstance)
	local componentId = #getmetatable(componentInstance)

	local record = world:ensureRecord(entityId)
	local sourceArchetype = record.archetype
	local destinationArchetype = archetypeTraverseAdd(world, componentId, sourceArchetype)

	if sourceArchetype == destinationArchetype then
		local archetypeRecord = destinationArchetype.records[componentId]
		destinationArchetype.columns[archetypeRecord][record.row] = componentInstance
		return
	end

	if sourceArchetype then
		moveEntity(world.entityIndex, entityId, record, destinationArchetype)
	else
		-- if it has any components, then it wont be the root archetype
		if #destinationArchetype.types > 0 then
			newEntity(entityId, record, destinationArchetype)
		end
	end

	local archetypeRecord = destinationArchetype.records[componentId]
	destinationArchetype.columns[archetypeRecord][record.row] = componentInstance
end

function World.ensureRecord(world: World, entityId: i53)
	local entityIndex = world.entityIndex
	local id = entityId
	if not entityIndex[id] then
		entityIndex[id] = {} :: Record
	end
	return entityIndex[id]
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

local function get(componentIndex: ComponentIndex, record: Record, componentId: i24): ComponentInstance?
	local archetype = record.archetype
	if archetype == nil then
		return nil
	end

	local archetypeRecord = archetype.records[componentId]
	if not archetypeRecord then
		return nil
	end

	return archetype.columns[archetypeRecord][record.row]
end

local function componentRemove(world: World, entityId: i53, component: Component)
	local componentId = #component
	local record = world:ensureRecord(entityId)
	local sourceArchetype = record.archetype
	local destinationArchetype = archetypeTraverseRemove(world, componentId, sourceArchetype)

	-- TODO:
	-- There is a better way to get the component for returning
	local componentInstance = get(world.componentIndex, record, componentId)
	if sourceArchetype and not (sourceArchetype == destinationArchetype) then
		moveEntity(world.entityIndex, entityId, record, destinationArchetype)
	end

	return componentInstance
end

--[=[
	Removes a component (or set of components) from an existing entity.

	```lua
	local removedA, removedB = world:remove(entityId, ComponentA, ComponentB)
	```

	@param entityId number -- The entity ID
	@param ... Component -- The components to remove
	@return ...ComponentInstance -- Returns the component instance values that were removed in the order they were passed.
]=]
function World.remove(world: World, entityId: i53, ...)
	if not world:contains(entityId) then
		error(ERROR_NO_ENTITY, 2)
	end

	local length = select("#", ...)
	local removed = {}
	for i = 1, length do
		table.insert(removed, componentRemove(world, entityId, select(i, ...)))
	end

	return unpack(removed, 1, length)
end

function World.get(
	world: World,
	entityId: i53,
	a: Component,
	b: Component?,
	c: Component?,
	d: Component?,
	e: Component?
): any
	local componentIndex = world.componentIndex
	local record = world.entityIndex[entityId]
	if not record then
		return nil
	end

	local va = get(componentIndex, record, #a)

	if b == nil then
		return va
	elseif c == nil then
		return va, get(componentIndex, record, #b)
	elseif d == nil then
		return va, get(componentIndex, record, #b), get(componentIndex, record, #c)
	elseif e == nil then
		return va, get(componentIndex, record, #b), get(componentIndex, record, #c), get(componentIndex, record, #d)
	else
		error("args exceeded")
	end
end

function World.insert(world: World, entityId: i53, ...)
	if not world:contains(entityId) then
		error(ERROR_NO_ENTITY, 2)
	end

	for i = 1, select("#", ...) do
		local newComponent = select(i, ...)
		assertValidComponentInstance(newComponent, i)

		local metatable = getmetatable(newComponent)
		local oldComponent = world:get(entityId, metatable)
		componentAdd(world, entityId, newComponent)

		world:_trackChanged(metatable, entityId, oldComponent, newComponent)
	end
end

function World.replace(world: World, entityId: i53, ...: ComponentInstance)
	error("Replace is unimplemented")

	if not world:contains(entityId) then
		error(ERROR_NO_ENTITY, 2)
	end

	--moveEntity(entityId, record, world.ROOT_ARCHETYPE)
	for i = 1, select("#", ...) do
		local newComponent = select(i, ...)
		assertValidComponentInstance(newComponent, i)
	end
end

function World.entity(world: World)
	world.nextId += 1
	return world.nextId
end

function World:__iter()
	return error("NOT IMPLEMENTED YET")
end

function World._trackChanged(world: World, metatable, id, old, new)
	if not world._changedStorage[metatable] then
		return
	end

	if old == new then
		return
	end

	local record = table.freeze({
		old = old,
		new = new,
	})

	for _, storage in ipairs(world._changedStorage[metatable]) do
		-- If this entity has changed since the last time this system read it,
		-- we ensure that the "old" value is whatever the system saw it as last, instead of the
		-- "old" value we have here.
		if storage[id] then
			storage[id] = table.freeze({ old = storage[id].old, new = new })
		else
			storage[id] = record
		end
	end
end

--[=[
	Spawns a new entity in the world with a specific entity ID and given components.

	The next ID generated from [World:spawn] will be increased as needed to never collide with a manually specified ID.

	@param entityId number -- The entity ID to spawn with
	@param ... ComponentInstance -- The component values to spawn the entity with.
	@return number -- The same entity ID that was passed in
]=]
function World.spawnAt(world: World, entityId: i53, ...: ComponentInstance)
	if world:contains(entityId) then
		error(string.format(ERROR_DUPLICATE_ENTITY, entityId), 2)
	end

	if entityId >= world.nextId then
		world.nextId = entityId + 1
	end

	world._size += 1
	world:ensureRecord(entityId)

	local components = {}
	for i = 1, select("#", ...) do
		local component = select(i, ...)
		assertValidComponentInstance(component, i)

		local metatable = getmetatable(component)
		if components[metatable] then
			error(("Duplicate component type at index %d"):format(i), 2)
		end

		world:_trackChanged(metatable, entityId, nil, component)

		components[metatable] = component
		componentAdd(world, entityId, component)
	end

	return entityId
end

--[=[
	Spawns a new entity in the world with the given components.

	@param ... ComponentInstance -- The component values to spawn the entity with.
	@return number -- The new entity ID.
]=]
function World.spawn(world: World, ...: ComponentInstance)
	return world:spawnAt(world.nextId, ...)
end

function World.despawn(world: World, entityId: i53)
	local entityIndex = world.entityIndex
	local record = entityIndex[entityId]
	moveEntity(entityIndex, entityId, record, world.ROOT_ARCHETYPE)
	world.ROOT_ARCHETYPE.entities[record.row] = nil
	entityIndex[entityId] = nil
	world._size -= 1
end

function World.clear(world: World)
	world.entityIndex = {}
	world.componentIndex = {}
	world.archetypes = {}
	world.archetypeIndex = {}
	world._size = 0
	world.ROOT_ARCHETYPE = archetypeOf(world, {}, nil)
end

function World.size(world: World)
	return world._size
end

function World.contains(world: World, entityId: i53)
	return world.entityIndex[entityId] ~= nil
end

local function noop(): any
	return function() end
end

local emptyQueryResult = setmetatable({
	next = function() end,
	snapshot = function()
		return {}
	end,
	without = function(self)
		return self
	end,
	view = function()
		return {
			get = function() end,
			contains = function() end,
		}
	end,
}, {
	__iter = noop,
	__call = noop,
})

local function queryResult(compatibleArchetypes, components: { number }, queryLength, ...): any
	local a: any, b: any, c: any, d: any, e: any = ...
	local lastArchetype, archetype = next(compatibleArchetypes)
	if not lastArchetype then
		return emptyQueryResult
	end

	local lastRow
	local queryOutput = {}
	local function iterate()
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

		if queryLength == 1 then
			return entityId, columns[archetypeRecords[a]][row]
		elseif queryLength == 2 then
			return entityId, columns[archetypeRecords[a]][row], columns[archetypeRecords[b]][row]
		elseif queryLength == 3 then
			return entityId,
				columns[archetypeRecords[a]][row],
				columns[archetypeRecords[b]][row],
				columns[archetypeRecords[c]][row]
		elseif queryLength == 4 then
			return entityId,
				columns[archetypeRecords[a]][row],
				columns[archetypeRecords[b]][row],
				columns[archetypeRecords[c]][row],
				columns[archetypeRecords[d]][row]
		elseif queryLength == 5 then
			return entityId,
				columns[archetypeRecords[a]][row],
				columns[archetypeRecords[b]][row],
				columns[archetypeRecords[c]][row],
				columns[archetypeRecords[d]][row],
				columns[archetypeRecords[e]][row]
		end

		for i, componentId in components do
			queryOutput[i] = columns[archetypeRecords[componentId]][row]
		end

		return entityId, unpack(queryOutput, 1, queryLength)
	end
	--[=[
		@class QueryResult

		A result from the [`World:query`](/api/World#query) function.

		Calling the table or the `next` method allows iteration over the results. Once all results have been returned, the
		QueryResult is exhausted and is no longer useful.

		```lua
		for id, enemy, charge, model in world:query(Enemy, Charge, Model) do
			-- Do something
		end
		```
	]=]
	local QueryResult = {}
	QueryResult.__index = QueryResult

	-- TODO:
	-- remove in matter 1.0
	function QueryResult:__call()
		return iterate()
	end

	function QueryResult:__iter()
		return function()
			return iterate()
		end
	end

	--[=[
		Returns an iterator that will skip any entities that also have the given components.

		@param ... Component -- The component types to filter against.
		@return () -> (id, ...ComponentInstance) -- Iterator of entity ID followed by the requested component values

		```lua
		for id in world:query(Target):without(Model) do
			-- Do something
		end
		```
	]=]
	function QueryResult:without(...)
		local components = { ... }
		for i, component in components do
			components[i] = #component
		end

		local compatibleArchetypes = compatibleArchetypes
		for i = #compatibleArchetypes, 1, -1 do
			local archetype = compatibleArchetypes[i]
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

		lastArchetype, archetype = next(compatibleArchetypes)
		if not lastArchetype then
			return emptyQueryResult
		end

		return self
	end

	--[=[
		Returns the next set of values from the query result. Once all results have been returned, the
		QueryResult is exhausted and is no longer useful.

		:::info
		This function is equivalent to calling the QueryResult as a function. When used in a for loop, this is implicitly
		done by the language itself.
		:::

		```lua
		-- Using world:query in this position will make Lua invoke the table as a function. This is conventional.
		for id, enemy, charge, model in world:query(Enemy, Charge, Model) do
			-- Do something
		end
		```

		If you wanted to iterate over the QueryResult without a for loop, it's recommended that you call `next` directly
		instead of calling the QueryResult as a function.
		```lua
		local id, enemy, charge, model = world:query(Enemy, Charge, Model):next()
		local id, enemy, charge, model = world:query(Enemy, Charge, Model)() -- Possible, but unconventional
		```

		@return id -- Entity ID
		@return ...ComponentInstance -- The requested component values
	]=]
	function QueryResult:next()
		return iterate()
	end

	local function drain()
		local entry = table.pack(iterate())
		return if entry.n > 0 then entry else nil
	end

	local Snapshot = {
		__iter = function(self): any
			local i = 0
			return function()
				i += 1

				local data = self[i] :: any

				if data then
					return unpack(data, 1, data.n)
				end

				return
			end
		end,
	}

	function QueryResult:snapshot()
		local list = setmetatable({}, Snapshot) :: any
		for entry in drain do
			table.insert(list, entry)
		end

		return list
	end

	--[=[
		Creates a View of the query and does all of the iterator tasks at once at an amortized cost.
		This is used for many repeated random access to an entity. If you only need to iterate, just use a query.

		```lua
		local inflicting = world:query(Damage, Hitting, Player):view()
		for _, source in world:query(DamagedBy) do
			local damage = inflicting:get(source.from)
		end

		for _ in world:query(Damage):view() do end -- You can still iterate views if you want!
		```
		
		@return View See [View](/api/View) docs.
	]=]
	function QueryResult:view()
		local fetches = {}
		local list = {} :: any

		local View = {}
		View.__index = View

		function View:__iter()
			local current = list.head
			return function()
				if not current then
					return
				end
				local entity = current.entity
				local fetch = fetches[entity]
				current = current.next

				return entity, unpack(fetch, 1, fetch.n)
			end
		end

		--[=[
			@within View
				Retrieve the query results to corresponding `entity`
			@param entity number - the entity ID
			@return ...ComponentInstance
		]=]
		function View:get(entity)
			if not self:contains(entity) then
				return
			end

			local fetch = fetches[entity]
			local queryLength = fetch.n

			if queryLength == 1 then
				return fetch[1]
			elseif queryLength == 2 then
				return fetch[1], fetch[2]
			elseif queryLength == 3 then
				return fetch[1], fetch[2], fetch[3]
			elseif queryLength == 4 then
				return fetch[1], fetch[2], fetch[3], fetch[4]
			elseif queryLength == 5 then
				return fetch[1], fetch[2], fetch[3], fetch[4], fetch[5]
			end

			return unpack(fetch, 1, fetch.n)
		end

		--[=[
			@within View
			Equivalent to `world:contains()`	
			@param entity number - the entity ID
			@return boolean 
		]=]
		function View:contains(entity)
			return fetches[entity] ~= nil
		end

		for entry in drain do
			local entityId = entry[1]
			local fetch = table.pack(select(2, unpack(entry)))
			local node = { entity = entityId, next = nil }
			fetches[entityId] = fetch

			if not list.head then
				list.head = node
			else
				local current = list.head
				while current.next do
					current = current.next
				end
				current.next = node
			end
		end

		return setmetatable({}, View)
	end

	return setmetatable({}, QueryResult)
end

--[=[
	Performs a query against the entities in this World. Returns a [QueryResult](/api/QueryResult), which iterates over
	the results of the query.

	Order of iteration is not guaranteed.

	```lua
	for id, enemy, charge, model in world:query(Enemy, Charge, Model) do
		-- Do something
	end

	for id in world:query(Target):without(Model) do
		-- Again, with feeling
	end
	```

	@param ... Component -- The component types to query. Only entities with *all* of these components will be returned.
	@return QueryResult -- See [QueryResult](/api/QueryResult) docs.
]=]
function World.query(world: World, ...: Component): any
	local compatibleArchetypes = {}
	local components = { ... }
	local archetypes = world.archetypes
	local queryLength = select("#", ...)
	local a: any, b: any, c: any, d: any, e: any = ...

	if queryLength == 0 then
		return emptyQueryResult
	end

	if queryLength == 1 then
		a = #a
		components = { a }
		-- local archetypesMap = world.componentIndex[a]
		-- components = { a }
		-- local function single()
		-- 	local id = next(archetypesMap)
		-- 	local archetype = archetypes[id :: number]
		-- 	local lastRow

		-- 	return function(): any
		-- 		local row, entity = next(archetype.entities, lastRow)
		-- 		while row == nil do
		-- 			id = next(archetypesMap, id)
		-- 			if id == nil then
		-- 				return
		-- 			end
		-- 			archetype = archetypes[id]
		-- 			row = next(archetype.entities, row)
		-- 		end
		-- 		lastRow = row

		-- 		return entity, archetype.columns[archetype.records[a]]
		-- 	end
		-- end
		-- return single()
	elseif queryLength == 2 then
		--print("iter double")
		a = #a
		b = #b
		components = { a, b }

		-- --print(a, b, world.componentIndex)
		-- --[[local archetypesMap = world.componentIndex[a]
		-- for id in archetypesMap do
		-- 	local archetype = archetypes[id]
		-- 	if archetype.records[b] then
		-- 		table.insert(compatibleArchetypes, archetype)
		-- 	end
		-- end

		-- local function double(): () -> (number, any, any)
		-- 	local lastArchetype, archetype = next(compatibleArchetypes)
		-- 	local lastRow

		-- 	return function()
		-- 		local row = next(archetype.entities, lastRow)
		-- 		while row == nil do
		-- 			lastArchetype, archetype = next(compatibleArchetypes, lastArchetype)
		-- 			if lastArchetype == nil then
		-- 				return
		-- 			end

		-- 			row = next(archetype.entities, row)
		-- 		end
		-- 		lastRow = row

		-- 		local entity = archetype.entities[row :: number]
		-- 		local columns = archetype.columns
		-- 		local archetypeRecords = archetype.records
		-- 		return entity, columns[archetypeRecords[a]], columns[archetypeRecords[b]]
		-- 	end
		-- end
		-- return double()
	elseif queryLength == 3 then
		a = #a
		b = #b
		c = #c
		components = { a, b, c }
	elseif queryLength == 4 then
		a = #a
		b = #b
		c = #c
		d = #d

		components = { a, b, c, d }
	elseif queryLength == 5 then
		a = #a
		b = #b
		c = #c
		d = #d
		e = #e

		components = { a, b, c, d, e }
	else
		for i, component in components do
			components[i] = (#component) :: any
		end
	end

	local firstArchetypeMap
	local componentIndex = world.componentIndex
	for _, componentId in (components :: any) :: { number } do
		local map = componentIndex[componentId]
		if not map then
			return emptyQueryResult
		end

		if firstArchetypeMap == nil or map.size < firstArchetypeMap.size then
			firstArchetypeMap = map
		end
	end

	for id in firstArchetypeMap.sparse do
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

	return queryResult(compatibleArchetypes, components :: any, queryLength, a, b, c, d, e)
end

local function cleanupQueryChanged(hookState)
	local world = hookState.world
	local componentToTrack = hookState.componentToTrack

	for index, object in world._changedStorage[componentToTrack] do
		if object == hookState.storage then
			table.remove(world._changedStorage[componentToTrack], index)
			break
		end
	end

	if next(world._changedStorage[componentToTrack]) == nil then
		world._changedStorage[componentToTrack] = nil
	end
end

function World.queryChanged(world: World, componentToTrack, ...: nil)
	if ... then
		error("World:queryChanged does not take any additional parameters", 2)
	end

	local hookState = topoRuntime.useHookState(componentToTrack, cleanupQueryChanged) :: any
	if hookState.storage then
		return function(): any
			local entityId, record = next(hookState.storage)

			if entityId then
				hookState.storage[entityId] = nil

				return entityId, record
			end
			return
		end
	end

	if not world._changedStorage[componentToTrack] then
		world._changedStorage[componentToTrack] = {}
	end

	local storage = {}
	hookState.storage = storage
	hookState.world = world
	hookState.componentToTrack = componentToTrack

	table.insert(world._changedStorage[componentToTrack], storage)

	local queryResult = world:query(componentToTrack)

	return function(): any
		local entityId, component = queryResult:next()

		if entityId then
			return entityId, table.freeze({ new = component })
		end
		return
	end
end
																								
return {
    World = World,
    component = newComponent
}
