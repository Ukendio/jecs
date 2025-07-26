# Observers

The observers addon extends the World with signal-based reactivity and query-based observers. This addon provides a more ergonomic way to handle component lifecycle events and query changes.

## Installation

The observers addon is included with jecs and can be imported directly:

```luau
local jecs = require(path/to/jecs)
local observers_add = require(path/to/jecs/addons/observers)

local world = observers_add(jecs.world())
```

## Methods

### added

Registers a callback that is invoked when a component is added to any entity.

```luau
function World:added<T>(
    component: Id<T>,
    callback: (entity: Entity, id: Id<T>, value: T?) -> ()
): () -> () -- Returns an unsubscribe function
```

**Parameters:**
- `component` - The component ID to listen for additions
- `callback` - Function called when component is added, receives entity, component ID, and value

**Returns:** An unsubscribe function that removes the listener when called

**Example:**
```luau
local Health = world:component() :: jecs.Entity<number>

local unsubscribe = world:added(Health, function(entity, id, value)
    print("Health component added to entity", entity, "with value", value)
end)

-- Later, to stop listening:
unsubscribe()
```

### removed

Registers a callback that is invoked when a component is removed from any entity.

```luau
function World:removed<T>(
    component: Id<T>,
    callback: (entity: Entity, id: Id<T>) -> ()
): () -> () -- Returns an unsubscribe function
```

**Parameters:**
- `component` - The component ID to listen for removals
- `callback` - Function called when component is removed, receives entity and component ID

**Returns:** An unsubscribe function that removes the listener when called

**Example:**
```luau
local Health = world:component() :: jecs.Entity<number>

local unsubscribe = world:removed(Health, function(entity, id)
    print("Health component removed from entity", entity)
end)
```

### changed

Registers a callback that is invoked when a component's value is changed on any entity.

```luau
function World:changed<T>(
    component: Id<T>,
    callback: (entity: Entity, id: Id<T>, value: T) -> ()
): () -> () -- Returns an unsubscribe function
```

**Parameters:**
- `component` - The component ID to listen for changes
- `callback` - Function called when component value changes, receives entity, component ID, and new value

**Returns:** An unsubscribe function that removes the listener when called

**Example:**
```luau
local Health = world:component() :: jecs.Entity<number>

local unsubscribe = world:changed(Health, function(entity, id, value)
    print("Health changed to", value, "for entity", entity)
end)
```

### observer

Creates a query-based observer that triggers when entities match or stop matching a query.

```luau
function World:observer<T...>(
    query: Query<T...>,
    callback: ((entity: Entity, id: Id, value: any?) -> ())?
): () -> () -> Entity -- Returns an iterator function
```

**Parameters:**
- `query` - The query to observe for changes
- `callback` - Optional function called when entities match the query

**Returns:** An iterator function that returns entities that matched the query since last iteration

**Example:**
```luau
local Position = world:component() :: jecs.Id<Vector3>
local Velocity = world:component() :: jecs.Id<Vector3>

local moving_entities = world:observer(
    world:query(Position, Velocity),
    function(entity, id, value)
        print("Entity", entity, "started moving")
    end
)

-- In your game loop:
for entity in moving_entities() do
    -- Process newly moving entities
end
```

### monitor

Creates a query-based monitor that triggers when entities are added to or removed from a query.

```luau
function World:monitor<T...>(
    query: Query<T...>,
    callback: ((entity: Entity, id: Id, value: any?) -> ())?
): () -> () -> Entity -- Returns an iterator function
```

**Parameters:**
- `query` - The query to monitor for additions/removals
- `callback` - Optional function called when entities are added or removed from the query

**Returns:** An iterator function that returns entities that were added or removed since last iteration

**Example:**
```luau
local Health = world:component() :: jecs.Id<number>

local health_changes = world:monitor(
    world:query(Health),
    function(entity, id, value)
        print("Health component changed for entity", entity)
    end
)

-- In your game loop:
for entity in health_changes() do
    -- Process entities with health changes
end
```

## Usage Patterns

### Component Lifecycle Tracking

```luau
local Player = world:component()
local Health = world:component() :: jecs.Id<number>

-- Track when players are created
world:added(Player, function(entity, id, instance)
	instance:SetAttribute("entityid", entity)
end)

world:removed(Player, function(entity, id)
	world:add(entity, Destroy) -- process its deletion later!
end)
```

## Performance Considerations

- **Signal listeners** are called immediately when components are added/removed/changed
- **Query observers** cache the query for better performance
- **Multiple listeners** for the same component are supported and called in registration order
- **Unsubscribe functions** should be called when listeners are no longer needed to prevent memory leaks
- **Observer iterators** should be called regularly to clear the internal buffer

## Integration with Built-in Hooks

The observers addon integrates with the built-in component hooks (`OnAdd`, `OnRemove`, `OnChange`). If a component already has these hooks configured, the observers addon will preserve them and call both the original hook and any registered signal listeners.
