
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

local valueIds = {}
local nextValueId = 0
local compatibilityCache = {}
local archetypeCache = {}

local function getValueId(value)
	local valueId = valueIds[value]
	if valueId == nil then
		valueIds[value] = nextValueId
		valueId = nextValueId
		nextValueId += 1
	end

	return valueId
end

function archetypeOf(...)
	local length = select("#", ...)

	local currentNode = archetypeCache

	for i = 1, length do
		local nextNode = currentNode[select(i, ...)]

		if not nextNode then
			nextNode = {}
			currentNode[select(i, ...)] = nextNode
		end

		currentNode = nextNode
	end

	if currentNode._archetype then
		return currentNode._archetype
	end

	local list = table.create(length)

	for i = 1, length do
		list[i] = getValueId(select(i, ...))
	end

	table.sort(list)

	local archetype = table.concat(list, "_")

	currentNode._archetype = archetype

	return archetype
end

function negateArchetypeOf(...)
	return string.gsub(archetypeOf(...), "_", "x")
end

function areArchetypesCompatible(queryArchetype, targetArchetype)
	local archetypes = string.split(queryArchetype, "x")
	local baseArchetype = table.remove(archetypes, 1)

	local cachedCompatibility = compatibilityCache[queryArchetype .. "-" .. targetArchetype]
	if cachedCompatibility ~= nil then
		return cachedCompatibility
	end

	local queryIds = string.split(baseArchetype, "_")
	local targetIds = toSet(string.split(targetArchetype, "_"))
	local excludeIds = toSet(archetypes)

	for _, queryId in ipairs(queryIds) do
		if targetIds[queryId] == nil then
			compatibilityCache[queryArchetype .. "-" .. targetArchetype] = false
			return false
		end
	end

	for excludeId in excludeIds do
		if targetIds[excludeId] then
			compatibilityCache[queryArchetype .. "-" .. targetArchetype] = false
			return false
		end
	end

	compatibilityCache[queryArchetype .. "-" .. targetArchetype] = true

	return true

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



local ERROR_NO_ENTITY = "Entity doesn't exist, use world:contains to check if needed"

--[=[
	@class World

	A World contains entities which have components.
	The World is queryable and can be used to get entities with a specific set of components.
	Entities are simply ever-increasing integers.
]=]
local World = {}
World.__index = World

--[=[
	Creates a new World.
]=]
function World.new()
	local firstStorage = {}

	return setmetatable({
		-- List of maps from archetype string --> entity ID --> entity data
		_storages = { firstStorage },
		-- The most recent storage that has not been dirtied by an iterator
		_pristineStorage = firstStorage,

		-- Map from entity ID -> archetype string
		_entityArchetypes = {},

		-- Cache of the component metatables on each entity. Used for generating archetype.
		-- Map of entity ID -> array
		_entityMetatablesCache = {},

		-- Cache of what query archetypes are compatible with what component archetypes
		_queryCache = {},

		-- Cache of what entity archetypes have ever existed in the game. This is used for knowing
		-- when to update the queryCache.
		_entityArchetypeCache = {},

		-- The next ID that will be assigned with World:spawn
		_nextId = 1,

		-- The total number of active entities in the world
		_size = 0,

		-- Storage for `queryChanged`
		_changedStorage = {},
	}, World)
end

-- Searches all archetype storages for the entity with the given archetype
-- Returns the storage that the entity is in if it exists, otherwise nil
function World:_getStorageWithEntity(archetype, id)
	for _, storage in self._storages do
		local archetypeStorage = storage[archetype]
		if archetypeStorage then
			if archetypeStorage[id] then
				return storage
			end
		end
	end
	return nil
end

function World:_markStorageDirty()
	local newStorage = {}
	table.insert(self._storages, newStorage)
	self._pristineStorage = newStorage

	if topoRuntime.withinTopoContext() then
		local frameState = topoRuntime.useFrameState()

		frameState.dirtyWorlds[self] = true
	end
end

function World:_getEntity(id)
	local archetype = self._entityArchetypes[id]
	local storage = self:_getStorageWithEntity(archetype, id)

	return storage[archetype][id]
end

function World:_next(last)
	local entityId, archetype = next(self._entityArchetypes, last)

	if entityId == nil then
		return nil
	end

	local storage = self:_getStorageWithEntity(archetype, entityId)

	return entityId, storage[archetype][entityId]
end

--[=[
	Iterates over all entities in this World. Iteration returns entity ID followed by a dictionary mapping
	Component to Component Instance.

	**Usage:**

	```lua
	for entityId, entityData in world do
		print(entityId, entityData[Components.Example])
	end
	```

	@return number
	@return {[Component]: ComponentInstance}
]=]
function World:__iter()
	return World._next, self
end

--[=[
	Spawns a new entity in the world with the given components.

	@param ... ComponentInstance -- The component values to spawn the entity with.
	@return number -- The new entity ID.
]=]
function World:spawn(...)
	return self:spawnAt(self._nextId, ...)
end

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

	setmetatable(component, {
		__call = function(_, ...)
			return component.new(...)
		end,
		__tostring = function()
			return name
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

--[=[
	Spawns a new entity in the world with a specific entity ID and given components.

	The next ID generated from [World:spawn] will be increased as needed to never collide with a manually specified ID.

	@param id number -- The entity ID to spawn with
	@param ... ComponentInstance -- The component values to spawn the entity with.
	@return number -- The same entity ID that was passed in
]=]
function World:spawnAt(id, ...)
	if self:contains(id) then
		error(
			string.format(
				"The world already contains an entity with ID %d. Use World:replace instead if this is intentional.",
				id
			),
			2
		)
	end

	self._size += 1

	if id >= self._nextId then
		self._nextId = id + 1
	end

	local components = {}
	local metatables = {}

	for i = 1, select("#", ...) do
		local newComponent = select(i, ...)

		assertValidComponentInstance(newComponent, i)

		local metatable = getmetatable(newComponent)

		if components[metatable] then
			error(("Duplicate component type at index %d"):format(i), 2)
		end

		self:_trackChanged(metatable, id, nil, newComponent)

		components[metatable] = newComponent
		table.insert(metatables, metatable)
	end

	self._entityMetatablesCache[id] = metatables

	self:_transitionArchetype(id, components)

	return id
end

function World:_newQueryArchetype(queryArchetype)
	if self._queryCache[queryArchetype] == nil then
		self._queryCache[queryArchetype] = {}
	else
		return -- Archetype isn't actually new
	end

	for _, storage in self._storages do
		for entityArchetype in storage do
			if areArchetypesCompatible(queryArchetype, entityArchetype) then
				self._queryCache[queryArchetype][entityArchetype] = true
			end
		end
	end
end

function World:_updateQueryCache(entityArchetype)
	for queryArchetype, compatibleArchetypes in pairs(self._queryCache) do
		if areArchetypesCompatible(queryArchetype, entityArchetype) then
			compatibleArchetypes[entityArchetype] = true
		end
	end
end

function World:_transitionArchetype(id, components)
	local newArchetype = nil
	local oldArchetype = self._entityArchetypes[id]
	local oldStorage

	if oldArchetype then
		oldStorage = self:_getStorageWithEntity(oldArchetype, id)

		if not components then
			oldStorage[oldArchetype][id] = nil
		end
	end

	if components then
		newArchetype = archetypeOf(unpack(self._entityMetatablesCache[id]))

		if oldArchetype ~= newArchetype then
			if oldStorage then
				oldStorage[oldArchetype][id] = nil
			end

			if self._pristineStorage[newArchetype] == nil then
				self._pristineStorage[newArchetype] = {}
			end

			if self._entityArchetypeCache[newArchetype] == nil then
				self._entityArchetypeCache[newArchetype] = true
				self:_updateQueryCache(newArchetype)
			end
			self._pristineStorage[newArchetype][id] = components
		else
			oldStorage[newArchetype][id] = components
		end
	end

	self._entityArchetypes[id] = newArchetype
end

--[=[
	Replaces a given entity by ID with an entirely new set of components.
	Equivalent to removing all components from an entity, and then adding these ones.

	@param id number -- The entity ID
	@param ... ComponentInstance -- The component values to spawn the entity with.
]=]
function World:replace(id, ...)
	if not self:contains(id) then
		error(ERROR_NO_ENTITY, 2)
	end

	local components = {}
	local metatables = {}
	local entity = self:_getEntity(id)

	for i = 1, select("#", ...) do
		local newComponent = select(i, ...)

		assertValidComponentInstance(newComponent, i)

		local metatable = getmetatable(newComponent)

		if components[metatable] then
			error(("Duplicate component type at index %d"):format(i), 2)
		end

		self:_trackChanged(metatable, id, entity[metatable], newComponent)

		components[metatable] = newComponent
		table.insert(metatables, metatable)
	end

	for metatable, component in pairs(entity) do
		if not components[metatable] then
			self:_trackChanged(metatable, id, component, nil)
		end
	end

	self._entityMetatablesCache[id] = metatables

	self:_transitionArchetype(id, components)
end

--[=[
	Despawns a given entity by ID, removing it and all its components from the world entirely.

	@param id number -- The entity ID
]=]
function World:despawn(id)
	local entity = self:_getEntity(id)

	for metatable, component in pairs(entity) do
		self:_trackChanged(metatable, id, component, nil)
	end

	self._entityMetatablesCache[id] = nil
	self:_transitionArchetype(id, nil)

	self._size -= 1
end

--[=[
	Removes all entities from the world.

	:::caution
	Removing entities in this way is not reported by `queryChanged`.
	:::
]=]
function World:clear()
	local firstStorage = {}
	self._storages = { firstStorage }
	self._pristineStorage = firstStorage
	self._entityArchetypes = {}
	self._entityMetatablesCache = {}
	self._size = 0
	self._changedStorage = {}
end

--[=[
	Checks if the given entity ID is currently spawned in this world.

	@param id number -- The entity ID
	@return bool -- `true` if the entity exists
]=]
function World:contains(id)
	return self._entityArchetypes[id] ~= nil
end

--[=[
	Gets a specific component (or set of components) from a specific entity in this world.

	@param id number -- The entity ID
	@param ... Component -- The components to fetch
	@return ... -- Returns the component values in the same order they were passed in
]=]
function World:get(id, ...)
	if not self:contains(id) then
		error(ERROR_NO_ENTITY, 2)
	end

	local entity = self:_getEntity(id)

	local length = select("#", ...)

	if length == 1 then
		assertValidComponent((...), 1)
		return entity[...]
	end

	local components = {}
	for i = 1, length do
		local metatable = select(i, ...)
		assertValidComponent(metatable, i)
		components[i] = entity[metatable]
	end

	return unpack(components, 1, length)
end

local function noop() end

local noopQuery = setmetatable({
	next = noop,
	snapshot = noop,
	without = function(self)
		return self
	end,
	view = {
		get = noop,
		contains = noop,
	},
}, {
	__iter = function()
		return noop
	end,
})

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

function QueryResult.new(world, expand, queryArchetype, compatibleArchetypes)
	return setmetatable({
		world = world,
		seenEntities = {},
		currentCompatibleArchetype = next(compatibleArchetypes),
		compatibleArchetypes = compatibleArchetypes,
		storageIndex = 1,
		_expand = expand,
		_queryArchetype = queryArchetype,
	}, QueryResult)
end

local function nextItem(query)
	local world = query.world
	local currentCompatibleArchetype = query.currentCompatibleArchetype
	local seenEntities = query.seenEntities
	local compatibleArchetypes = query.compatibleArchetypes

	local entityId, entityData

	local storages = world._storages
	repeat
		local nextStorage = storages[query.storageIndex]
		local currently = nextStorage[currentCompatibleArchetype]
		if currently then
			entityId, entityData = next(currently, query.lastEntityId)
		end

		while entityId == nil do
			currentCompatibleArchetype = next(compatibleArchetypes, currentCompatibleArchetype)

			if currentCompatibleArchetype == nil then
				query.storageIndex += 1

				nextStorage = storages[query.storageIndex]

				if nextStorage == nil or next(nextStorage) == nil then
					return
				end

				currentCompatibleArchetype = nil

				if world._pristineStorage == nextStorage then
					world:_markStorageDirty()
				end

				continue
			elseif nextStorage[currentCompatibleArchetype] == nil then
				continue
			end

			entityId, entityData = next(nextStorage[currentCompatibleArchetype])
		end

		query.lastEntityId = entityId

	until seenEntities[entityId] == nil

	query.currentCompatibleArchetype = currentCompatibleArchetype

	seenEntities[entityId] = true

	return entityId, entityData
end

function QueryResult:__iter()
	return function()
		return self._expand(nextItem(self))
	end
end

function QueryResult:__call()
	return self._expand(nextItem(self))
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
	return self._expand(nextItem(self))
end

local snapshot = {
	__iter = function(self): any
		local i = 0
		return function()
			i += 1

			local data = self[i]

			if data then
				return unpack(data, 1, data.n)
			end
			return
		end
	end,
}

--[=[
	Creates a "snapshot" of this query, draining this QueryResult and returning a list containing all of its results.

	By default, iterating over a QueryResult happens in "real time": it iterates over the actual data in the ECS, so
	changes that occur during the iteration will affect future results.

	By contrast, `QueryResult:snapshot()` creates a list of all of the results of this query at the moment it is called,
	so changes made while iterating over the result of `QueryResult:snapshot` do not affect future results of the
	iteration.

	Of course, this comes with a cost: we must allocate a new list and iterate over everything returned from the
	QueryResult in advance, so using this method is slower than iterating over a QueryResult directly.

	The table returned from this method has a custom `__iter` method, which lets you use it as you would use QueryResult
	directly:

	```lua
		for entityId, health, player in world:query(Health, Player):snapshot() do

		end
	```

	However, the table itself is just a list of sub-tables structured like `{entityId, component1, component2, ...etc}`.

	@return {{entityId: number, component: ComponentInstance, component: ComponentInstance, component: ComponentInstance, ...}}
]=]
function QueryResult:snapshot()
	local list = setmetatable({}, snapshot)

	local function iter()
		return nextItem(self)
	end

	for entityId, entityData in iter do
		if entityId then
			table.insert(list, table.pack(self._expand(entityId, entityData)))
		end
	end

	return list
end

--[=[
	Returns an iterator that will skip any entities that also have the given components.

	:::tip
	This is essentially equivalent to querying normally, using `World:get` to check if a component is present,
	and using Lua's `continue` keyword to skip this iteration (though, using `:without` is faster).

	This means that you should avoid queries that return a very large amount of results only to filter them down
	to a few with `:without`. If you can, always prefer adding components and making your query more specific.
	:::

	@param ... Component -- The component types to filter against.
	@return () -> (id, ...ComponentInstance) -- Iterator of entity ID followed by the requested component values

	```lua
	for id in world:query(Target):without(Model) do
		-- Do something
	end
	```
]=]

function QueryResult:without(...)
	local world = self.world
	local filter = negateArchetypeOf(...)

	local negativeArchetype = `{self._queryArchetype}x{filter}`

	if world._queryCache[negativeArchetype] == nil then
		world:_newQueryArchetype(negativeArchetype)
	end

	local compatibleArchetypes = world._queryCache[negativeArchetype]

	self.compatibleArchetypes = compatibleArchetypes
	self.currentCompatibleArchetype = next(compatibleArchetypes)
	return self
end

--[=[
	@class View

	Provides random access to the results of a query.

	Calling the View is equivalent to iterating a query. 

	```lua
	for id, player, health, poison in world:query(Player, Health, Poison):view() do
		-- Do something
	end
	```
]=]

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
	local function iter()
		return nextItem(self)
	end

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

	for entityId, entityData in iter do
		if entityId then
			-- We start at 2 on Select since we don't need want to pack the entity id.
			local fetch = table.pack(select(2, self._expand(entityId, entityData)))
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
	end

	return setmetatable({}, View)
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

function World:query(...)
	assertValidComponent((...), 1)

	local metatables = { ... }
	local queryLength = select("#", ...)

	local archetype = archetypeOf(...)

	if self._queryCache[archetype] == nil then
		self:_newQueryArchetype(archetype)
	end

	local compatibleArchetypes = self._queryCache[archetype]

	if next(compatibleArchetypes) == nil then
		-- If there are no compatible storages avoid creating our complicated iterator
		return noopQuery
	end

	local queryOutput = table.create(queryLength)

	local function expand(entityId, entityData)
		if not entityId then
			return
		end

		if queryLength == 1 then
			return entityId, entityData[metatables[1]]
		elseif queryLength == 2 then
			return entityId, entityData[metatables[1]], entityData[metatables[2]]
		elseif queryLength == 3 then
			return entityId, entityData[metatables[1]], entityData[metatables[2]], entityData[metatables[3]]
		elseif queryLength == 4 then
			return entityId,
				entityData[metatables[1]],
				entityData[metatables[2]],
				entityData[metatables[3]],
				entityData[metatables[4]]
		elseif queryLength == 5 then
			return entityId,
				entityData[metatables[1]],
				entityData[metatables[2]],
				entityData[metatables[3]],
				entityData[metatables[4]],
				entityData[metatables[5]]
		end

		for i, metatable in ipairs(metatables) do
			queryOutput[i] = entityData[metatable]
		end

		return entityId, unpack(queryOutput, 1, queryLength)
	end

	if self._pristineStorage == self._storages[1] then
		self:_markStorageDirty()
	end

	return QueryResult.new(self, expand, archetype, compatibleArchetypes)
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

--[=[
	@interface ChangeRecord
	@within World
	.new? ComponentInstance -- The new value of the component. Nil if just removed.
	.old? ComponentInstance -- The former value of the component. Nil if just added.
]=]

--[=[
	:::info Topologically-aware function
	This function is only usable if called within the context of [`Loop:begin`](/api/Loop#begin).
	:::

	Queries for components that have changed **since the last time your system ran `queryChanged`**.

	Only one changed record is returned per entity, even if the same entity changed multiple times. The order
	in which changed records are returned is not guaranteed to be the order that the changes occurred in.

	It should be noted that `queryChanged` does not have the same iterator invalidation concerns as `World:query`.

	:::tip
	The first time your system runs (i.e., on the first frame), all existing entities in the world that match your query
	are returned as "new" change records.
	:::

	:::info
	Calling this function from your system creates storage internally for your system. Then, changes meeting your
	criteria are pushed into your storage. Calling `queryChanged` again each frame drains this storage.

	If your system isn't called every frame, the storage will continually fill up and does not empty unless you drain
	it.

	If you stop calling `queryChanged` in your system, changes will stop being tracked.
	:::

	### Returns
	`queryChanged` returns an iterator function, so you call it in a for loop just like `World:query`.

	The iterator returns the entity ID, followed by a [`ChangeRecord`](#ChangeRecord).

	The `ChangeRecord` type is a table that contains two fields, `new` and `old`, respectively containing the new
	component instance, and the old component instance. `new` and `old` will never be the same value.

	`new` will be nil if the component was removed (or the entity was despawned), and `old` will be nil if the
	component was just added.

	The `old` field will be the value of the component the last time this system observed it, not
	necessarily the value it changed from most recently.

	The `ChangeRecord` table is potentially shared with multiple systems tracking changes for this component, so it
	cannot be modified.

	```lua
	for id, record in world:queryChanged(Model) do
		if record.new == nil then
			-- Model was removed

			if enemy.type == "this is a made up example" then
				world:remove(id, Enemy)
			end
		end
	end
	```

	@param componentToTrack Component -- The component you want to listen to changes for.
	@return () -> (id, ChangeRecord) -- Iterator of entity ID and change record
]=]
function World:queryChanged(componentToTrack, ...: nil)
	if ... then
		error("World:queryChanged does not take any additional parameters", 2)
	end

	local hookState = topoRuntime.useHookState(componentToTrack, cleanupQueryChanged)

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

	if not self._changedStorage[componentToTrack] then
		self._changedStorage[componentToTrack] = {}
	end

	local storage = {}
	hookState.storage = storage
	hookState.world = self
	hookState.componentToTrack = componentToTrack

	table.insert(self._changedStorage[componentToTrack], storage)

	local queryResult = self:query(componentToTrack)

	return function(): any
		local entityId, component = queryResult:next()

		if entityId then
			return entityId, table.freeze({ new = component })
		end
		return
	end
end

function World:_trackChanged(metatable, id, old, new)
	if not self._changedStorage[metatable] then
		return
	end

	if old == new then
		return
	end

	local record = table.freeze({
		old = old,
		new = new,
	})

	for _, storage in ipairs(self._changedStorage[metatable]) do
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
	Inserts a component (or set of components) into an existing entity.

	If another instance of a given component already exists on this entity, it is replaced.

	```lua
	world:insert(
		entityId,
		ComponentA({
			foo = "bar"
		}),
		ComponentB({
			baz = "qux"
		})
	)
	```

	@param id number -- The entity ID
	@param ... ComponentInstance -- The component values to insert
]=]
function World:insert(id, ...)
	if not self:contains(id) then
		error(ERROR_NO_ENTITY, 2)
	end

	local entity = self:_getEntity(id)

	local wasNew = false
	for i = 1, select("#", ...) do
		local newComponent = select(i, ...)

		assertValidComponentInstance(newComponent, i)

		local metatable = getmetatable(newComponent)

		local oldComponent = entity[metatable]

		if not oldComponent then
			wasNew = true

			table.insert(self._entityMetatablesCache[id], metatable)
		end

		self:_trackChanged(metatable, id, oldComponent, newComponent)

		entity[metatable] = newComponent
	end

	if wasNew then -- wasNew
		self:_transitionArchetype(id, entity)
	end
end

--[=[
	Removes a component (or set of components) from an existing entity.

	```lua
	local removedA, removedB = world:remove(entityId, ComponentA, ComponentB)
	```

	@param id number -- The entity ID
	@param ... Component -- The components to remove
	@return ...ComponentInstance -- Returns the component instance values that were removed in the order they were passed.
]=]
function World:remove(id, ...)
	if not self:contains(id) then
		error(ERROR_NO_ENTITY, 2)
	end

	local entity = self:_getEntity(id)

	local length = select("#", ...)
	local removed = {}

	for i = 1, length do
		local metatable = select(i, ...)

		assertValidComponent(metatable, i)

		local oldComponent = entity[metatable]

		removed[i] = oldComponent

		self:_trackChanged(metatable, id, oldComponent, nil)

		entity[metatable] = nil
	end

	-- Rebuild entity metatable cache
	local metatables = {}

	for metatable in pairs(entity) do
		table.insert(metatables, metatable)
	end

	self._entityMetatablesCache[id] = metatables

	self:_transitionArchetype(id, entity)

	return unpack(removed, 1, length)
end

--[=[
	Returns the number of entities currently spawned in the world.
]=]
function World:size()
	return self._size
end

--[=[
	:::tip
	[Loop] automatically calls this function on your World(s), so there is no need to call it yourself if you're using
	a Loop.
	:::

	If you are not using a Loop, you should call this function at a regular interval (i.e., once per frame) to optimize
	the internal storage for queries.

	This is part of a strategy to eliminate iterator invalidation when modifying the World while inside a query from
	[World:query]. While inside a query, any changes to the World are stored in a separate location from the rest of
	the World. Calling this function combines the separate storage back into the main storage, which speeds things up
	again.
]=]
function World:optimizeQueries()
	if #self._storages == 1 then
		return
	end

	local firstStorage = self._storages[1]

	for i = 2, #self._storages do
		local storage = self._storages[i]

		for archetype, entities in storage do
			if firstStorage[archetype] == nil then
				firstStorage[archetype] = entities
			else
				for entityId, entityData in entities do
					if firstStorage[archetype][entityId] then
						error("Entity ID already exists in first storage...")
					end
					firstStorage[archetype][entityId] = entityData
				end
			end
		end
	end

	table.clear(self._storages)

	self._storages[1] = firstStorage
	self._pristineStorage = firstStorage
end

return {
    World = World,
    component = newComponent
}
