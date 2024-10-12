# Query

A World contains entities which have components. The World is queryable and can be used to get entities with a specific set of components.

# Methods

## with
Adds components (IDs) to query with, but will not use their data. This is useful for Tags or generally just data you do not care for.

```luau
function query:with(
    ...: Entity -- The IDs to query with
): Query
```

Example:
::: code-group

```luau [luau]
for id, position in world:query(Position):with(Velocity) do
    -- Do something
end
```

```ts [typescript]
for (const [id, position] of world.query(Position).with(Velocity)) {
    // Do something
}
```

:::

:::info
Put the IDs inside of `world:query()` instead if you need the data.
:::

## without
Removes entities with the provided components from the query.

```luau
function query:without(
    ...: Entity -- The IDs to filter against.
): Query -- Returns the Query
```

Example:

::: code-group
```luau [luau]
for entity, position in world:query(Position):without(Velocity) do
    -- Do something
end
```

```ts [typescript]
for (const [entity, position] of world.query(Position).without(Velocity)) {
    // Do something
}
```
:::

## archetypes
Returns the matching archetypes of the query.
```luau
function query:archetypes(): { Archetype }
```

Example:

```luau [luau]
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

:::info
This function is meant for people who wants to really customize their query behaviour at the archetype-level
:::
