# Query

A World contains entities which have components. The World is queryable and can be used to get entities with a specific set of components.

To create a query, you must utilize [`world:query`](world).

## Methods

### drain
This method will impede it from being reset when the query is being iterated.
```luau
function query:drain(): Query
```

### next
Get the next result in the query. Drain must have been called beforehand or otherwise it will error.
```luau
function query:next(): Query
```

### with
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

### without
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

### replace
This function takes a callback which is given the current queried data of each matching entity. The values returned by the callback will be set as the new data for each given ID on the entity.
```luau
function query:replace(
    fn: (entity: Entity, ...: T...) -> U... -- ): () -- The callback that will transform the entities' data
```

Example:

::: code-group
```luau [luau]
world:query(Position, Velocity):replace(function(e, position, velocity)
    return position + velocity, velocity * 0.9
end
```

```ts [typescript]
world
    .query(Position, Velocity)
    .replace((e, position, velocity) =>
        $tuple(position.add(velocity), velocity.mul(0.9)),
    );
```
:::

### archetypes
Returns the matching archetypes of the query.
```luau
function query.archetypes(): { Archetype }
```

Example:

::: code-group
```luau [luau]
for i, archetype in world:query(Position, Velocity).archetypes() do
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

```ts [typescript]
for (const [i, archetype] of world.query(Position, Velocity).archetypes()) {
    const columns = archetype.columns;
    const field = archetype.records;

    const P = field[Position];
    const V = field[Velocity];

    for (const [row, entity] of archetype.entities) {
        local position = columns[P][row];
        local velocity = columns[V][row];
        // Do something
    }
}
```
:::

:::info
This function is meant for internal usage. Use this if you want to maximize performance by inlining the iterator.
:::
