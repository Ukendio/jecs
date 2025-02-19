# Query API

Queries allow you to efficiently find and iterate over entities that have a specific set of components.

## Methods

### iter()
```luau
function Query:iter(): () -> (Entity, ...)
```

Returns an iterator that yields matching entities and their component values.

Example:
::: code-group
```luau [luau]
for id, position, velocity in world:query(Position, Velocity):iter() do
    -- Do something with position and velocity
end
```
```typescript [typescript]
for (const [id, position, velocity] of world.query(Position, Velocity)) {
    // Do something with position and velocity
}
```
:::

### with()
```luau
function Query:with(...: Entity): Query
```

Adds components to filter by, but doesn't return their values in iteration. Useful for filtering by tags.

Example:
::: code-group
```luau [luau]
-- Only get position for entities that also have Velocity
for id, position in world:query(Position):with(Velocity) do
    -- Do something with position
end
```
```typescript [typescript]
for (const [id, position] of world.query(Position).with(Velocity)) {
    // Do something with position
}
```
:::

### without()
```luau
function Query:without(...: Entity): Query
```

Excludes entities that have any of the specified components.

Example:
::: code-group
```luau [luau]
-- Get position for entities that don't have Velocity
for id, position in world:query(Position):without(Velocity) do
    -- Do something with position
end
```
```typescript [typescript]
for (const [id, position] of world.query(Position).without(Velocity)) {
    // Do something with position
}
```
:::

### cached()
```luau
function Query:cached(): Query
```

Returns a cached version of the query for better performance when using the same query multiple times.

### archetypes()
```luau
function Query:archetypes(): { Archetype }
```

Returns the matching archetypes for low-level query customization.

:::info
This method is for advanced users who need fine-grained control over query behavior at the archetype level.
:::

Example:
```luau
for i, archetype in world:query(Position, Velocity):archetypes() do
    local columns = archetype.columns
    local field = archetype.records

    local P = field[Position]
    local V = field[Velocity]

    for row, entity in archetype.entities do
        local position = columns[P][row]
        local velocity = columns[V][row]
        -- Do something
    end
end
```
