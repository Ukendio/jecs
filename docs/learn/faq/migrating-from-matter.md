# Migrating from Matter

This guide helps you migrate your code from Matter ECS to Jecs.

## Key Differences

### World Creation
```lua
-- Matter
local world = Matter.World.new()

-- Jecs
local world = jecs.World.new()
```

### Component Definition
```lua
-- Matter
local Position = { name = "Position" }
local Velocity = { name = "Velocity" }

-- Jecs
local Position = world:component() :: jecs.Entity<Vector3>
local Velocity = world:component() :: jecs.Entity<Vector3>
```

### Entity Creation
```lua
-- Matter
local entity = world:spawn()

-- Jecs
local entity = world:entity()
```

### Adding Components
```lua
-- Matter
world:insert(entity, Position, { x = 0, y = 0, z = 0 })

-- Jecs
world:set(entity, Position, Vector3.new(0, 0, 0))
```

### Querying
```lua
-- Matter
for id, pos, vel in world:query(Position, Velocity) do
    -- Process entities
end

-- Jecs
for id, pos, vel in world:query(Position, Velocity) do
    -- Process entities
end
```

## Major Feature Differences

### Relationships
Jecs provides built-in support for entity relationships:
```lua
-- Jecs only
world:add(child, pair(ChildOf, parent))
```

### Component Traits
Jecs allows adding traits to components:
```lua
-- Jecs only
world:add(Position, Networked)
```

### Query Caching
Jecs provides explicit query caching:
```lua
-- Jecs only
local cachedQuery = world:query(Position, Velocity):cached()
```

## Migration Steps

1. **Update Component Definitions**
   - Replace Matter component tables with Jecs components
   - Add type annotations for better type safety

2. **Update Entity Management**
   - Replace `spawn()` with `entity()`
   - Update component insertion syntax

3. **Update Queries**
   - Review and update query usage
   - Consider using query caching for performance

4. **Add Relationships**
   - Replace custom parent-child implementations with Jecs relationships
   - Use built-in relationship features

5. **Update Systems**
   - Review system implementation patterns
   - Consider using component traits for better organization

## Performance Considerations

1. **Query Performance**
   - Cache frequently used queries
   - Use appropriate filters

2. **Component Storage**
   - Use tags for boolean states
   - Consider component data structure size

3. **Relationship Usage**
   - Be mindful of relationship complexity
   - Use built-in relationships when possible

## Getting Help

Need help migrating?
- Join our [Discord server](https://discord.gg/h2NV8PqhAD)
- Check the [API documentation](../../api/jecs.md)
- Open an issue on [GitHub](https://github.com/ukendio/jecs/issues) 