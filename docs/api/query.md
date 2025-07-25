# Query

A World contains entities which have components. The World is queryable and can be used to get entities with a specific set of components.

# Methods

## cached

Returns a cached version of the query. This is useful if you want to create a query that you can iterate multiple times.

```luau
function Query:cached(): Query -- Returns the cached Query
```
Example:

```luau [luau]
local lerps = world:query(Lerp):cached() -- Ensure that you cache this outside a system so you do not create a new cache for a query every frame

local function system(dt)
	for entity, lerp in lerps do
		-- Do something
	end
end
```

```ts [typescript]
const lerps = world.query(Lerp).cached()

function system(dt) {
	for (const [entity, lerp] of lerps) {
		// Do something
	}
}

## with

Adds components (IDs) to query with, but will not use their data. This is useful for Tags or generally just data you do not care for.

```luau
function Query:with(
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
function Query:without(
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
function Query:archetypes(): { Archetype }
```

Example:

```luau [luau]
for i, archetype in world:query(Position, Velocity):archetypes() do
    local field = archetype.columns_map
    local positions = field[Position]
    local velocities = field[Velocity]

    for row, entity in archetype.entities do
        local position = positions[row]
        local velocity = velocities[row]
        -- Do something
    end
end
```

:::info
This function is meant for people who want to really customize their query behaviour at the archetype-level
:::

## iter

If you are on the old solver, to get types for the returned values, requires usage of `:iter` to get an explicit returntype of an iterator function.

```luau
function Query:iter(): () -> (Entity, ...)
```
