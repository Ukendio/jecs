    # Query

A World contains entities which have components. The World is queryable and can be used to get entities with a specific set of components.

## Functions

### drain()
```luau
function query:drain(): Query
```
This function will impede it from being reset when the query is being iterated.

### next()
```luau
function query:next(): Query
```
Get the next result in the query. Drain must have been called beforehand or otherwise it will error.

### with()
```luau
function query:with(
    ...: Entity -- The IDs to query with
): Query
```
Adds IDs to query with, but will not use their data. This is useful for Tags or generally just data you do not care for.

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

### without()

```luau
function query:without(
    ...: Entity -- The IDs to filter against.
): Query -- Returns the Query
```
Removes entities with the provided IDs from the query.

Example:
::: code-group

```luau [luau]
for _ in world:query(Position):without(Velocity) do
    -- Do something
end
```

```ts [typescript]
for (const _ of world.query(Position).without(Velocity)) {
    // Do something
}
```

:::

### replace()

```luau
function query:replace(
    fn: (entity: Entity, ...: T...) -> U... -- ): () -- The callback that will transform the entities' data
```
This function takes a callback which is given the current queried data of each matching entity. The values returned by the callback will be set as the new data for each given ID on the entity.

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


### archetypes()
```luau
function query.archetypes(): { Archetype }
```
Returns the matching archetypes of the query.

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

:::

:::info
This function is meant for internal usage. Use this if you want to maximize performance by inlining the iterator.
:::
