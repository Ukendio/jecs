# Migrating from Matter to jecs

This guide is intended to help developers migrate from the Matter ECS library to jecs.

## Key Differences

### Architectural Differences

- **Storage Implementation**: jecs uses an archetype-based storage system (SoA - Structure of Arrays). Matter uses a simpler component-based storage approach.
- **Performance**: jecs is designed with a focus on performance, particularly for large-scale systems with hundreds of thousands of entities.
- **Relationship Model**: jecs treats entity relationships as first-class citizens. Matter doesn't have built-in relationship features.
- **Memory Usage**: jecs typically uses less memory for the same number of entities and components due to its optimized storage structure.

### API Differences

#### World Creation and Management

**Matter:**
```lua
local Matter = require("Matter")
local world = Matter.World.new()
```

**jecs:**
```lua
local jecs = require("jecs")
local world = jecs.World.new()
```

#### Component Definition

**Matter:**
```lua
local Position = Matter.component("Position")
local Velocity = Matter.component("Velocity") 
```

**jecs:**
```lua
local Position = world:component()
local Velocity = world:component()
```

#### Entity Creation

**Matter:**
```lua
local entity = world:spawn(
  Position({x = 0, y = 0}),
  Velocity({x = 10, y = 5})
)
```

**jecs:**
```lua
local entity = world:entity()
world:set(entity, Position, {x = 0, y = 0})
world:set(entity, Velocity, {x = 10, y = 5})
```

#### Queries

**Matter:**
```lua
for id, position, velocity in world:query(Position, Velocity) do
  -- Update position based on velocity
  position.x = position.x + velocity.x * dt
  position.y = position.y + velocity.y * dt
end
```

**jecs:**
```lua
for entity, position, velocity in world:query(Position, Velocity) do
  -- Update position based on velocity
  position.x = position.x + velocity.x * dt
  position.y = position.y + velocity.y * dt
end
```

#### System Definition

**Matter:**
```lua
local function movementSystem(world)
  for id, position, velocity in world:query(Position, Velocity) do
    position.x = position.x + velocity.x * dt
    position.y = position.y + velocity.y * dt
  end
end
```

**jecs:**
```lua
local function movementSystem(world, dt)
  for entity, position, velocity in world:query(Position, Velocity) do
    position.x = position.x + velocity.x * dt
    position.y = position.y + velocity.y * dt
  end
end
```

#### Entity Removal

**Matter:**
```lua
world:despawn(entity)
```

**jecs:**
```lua
world:delete(entity)
```

#### Component Removal

**Matter:**
```lua
world:remove(entity, Position)
```

**jecs:**
```lua
world:remove(entity, Position)
```

### jecs-Specific Features

#### Relationships

jecs has built-in support for entity relationships:

```lua
local ChildOf = world:component()
local Name = world:component()

local parent = world:entity()
world:set(parent, Name, "Parent")

local child = world:entity()
world:add(child, jecs.pair(ChildOf, parent))
world:set(child, Name, "Child")

-- Query for all children of parent
for e in world:query(jecs.pair(ChildOf, parent)) do
  local name = world:get(e, Name)
  print(name, "is a child of Parent")
end
```

#### Wildcards

jecs supports wildcard queries for relationships:

```lua
-- Query for all parent-child relationships
for entity, target in world:query(jecs.pair(ChildOf, jecs.Wildcard)) do
  print(world:get(entity, Name), "is a child of", world:get(target, Name))
end

-- Alternative using the shorter 'w' alias
for entity, target in world:query(jecs.pair(ChildOf, jecs.w)) do
  print(world:get(entity, Name), "is a child of", world:get(target, Name))
end
```

#### Observer Hooks

jecs provides component lifecycle hooks:

```lua
world:set(Position, jecs.OnAdd, function(entity)
  print("Position added to entity", entity)
end)

world:set(Position, jecs.OnRemove, function(entity)
  print("Position removed from entity", entity)
end)

world:set(Position, jecs.OnSet, function(entity, value)
  print("Position set on entity", entity, "with value", value)
end)
```

#### Automatic Cleanup with OnDelete and OnDeleteTarget

jecs offers automated cleanup of related entities:

```lua
-- When a parent is deleted, all its children will be deleted too
world:add(ChildOf, jecs.pair(jecs.OnDeleteTarget, jecs.Delete))

-- When Health component is deleted, remove the entity's Shield component
world:add(Health, jecs.pair(jecs.OnDelete, jecs.Remove))
world:add(Shield, jecs.pair(jecs.OnDelete, jecs.Remove))
```

## Performance Considerations

When migrating from Matter to jecs, consider these performance tips:

1. **Batch Entity Operations**: Group entity operations when possible to minimize archetype transitions.
2. **Use Cached Queries**: For frequently used queries, create cached versions.
3. **Consider Component Layout**: Components frequently queried together should be defined together.
4. **Use Tags When Appropriate**: For components with no data, use tags instead of empty tables.
5. **Be Aware of Archetype Transitions**: Adding/removing components causes archetype transitions, which have performance implications for large-scale operations.

## Migration Strategy

1. **Start with World Creation**: Replace Matter's world creation with jecs.
2. **Migrate Component Definitions**: Update component definitions to use jecs's approach.
3. **Update Entity Creation**: Modify entity spawning code to use jecs's entity and set methods.
4. **Adapt Queries**: Update queries, noting that iteration patterns are similar.
5. **Implement Relationships**: Take advantage of jecs's relationship features where applicable.
6. **Add Observer Hooks**: Implement lifecycle hooks to replace custom event handling in Matter.
7. **Optimize**: Refine your implementation using jecs-specific features for better performance.

By following this guide, you should be able to migrate your Matter ECS application to jecs while taking advantage of jecs's enhanced performance and features. 