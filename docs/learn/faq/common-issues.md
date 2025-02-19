# Common Issues

This guide covers common issues you might encounter when using Jecs and their solutions.

## Performance Issues

### Query Performance

**Issue**: Queries are running slower than expected

**Solutions**:
1. Cache frequently used queries:
```lua
local movementQuery = world:query(Position, Velocity):cached()
```

2. Use `with()` for components you don't need values from:
```lua
-- Instead of
for id, pos, _ in world:query(Position, IsEnemy) do end

-- Use
for id, pos in world:query(Position):with(IsEnemy) do end
```

3. Minimize relationship complexity to reduce archetype fragmentation

### Memory Usage

**Issue**: High memory usage with many entities

**Solutions**:
1. Use tags instead of boolean components
2. Call `world:cleanup()` periodically to remove empty archetypes
3. Consider component data structure size

## Type Issues

### Component Type Errors

**Issue**: Type errors with components

**Solutions**:
1. Always specify component types:
```lua
local Health = world:component() :: jecs.Entity<number>
local Position = world:component() :: jecs.Entity<Vector3>
```

2. Use correct types in set operations:
```lua
-- Correct
world:set(entity, Position, Vector3.new(0, 0, 0))

-- Wrong
world:set(entity, Position, {x=0, y=0, z=0})
```

## Relationship Issues

### Missing Targets

**Issue**: Cannot find relationship targets

**Solutions**:
1. Use `world:target()` to get relationship targets:
```lua
local parent = world:target(entity, ChildOf)
```

2. Check relationship existence:
```lua
if world:has(entity, pair(ChildOf, parent)) then
    -- Process relationship
end
```

### Cleanup Issues

**Issue**: Entities not cleaning up properly

**Solutions**:
1. Configure cleanup traits:
```lua
world:add(ChildOf, pair(jecs.OnDeleteTarget, jecs.Delete))
```

2. Manually clean up relationships before deleting entities:
```lua
world:clear(entity) -- Remove all components
world:delete(entity) -- Then delete entity
```

## Best Practices

### Query Organization
- Cache frequently used queries
- Use appropriate filters (`with`/`without`)
- Consider component order in queries

### Component Design
- Keep components small and focused
- Use tags for boolean states
- Document component types

### Memory Management
- Clean up unused entities
- Configure appropriate cleanup traits
- Monitor archetype fragmentation

## Getting Help

If you encounter issues not covered here:
1. Check the [API documentation](../../api/jecs.md)
2. Join our [Discord server](https://discord.gg/h2NV8PqhAD)
3. Open an issue on [GitHub](https://github.com/ukendio/jecs/issues) 