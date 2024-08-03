# World

A World contains entities which have components. The World is queryable and can be used to get entities with a specific set of components.

## Functions

### new()
```luau
function World.new(): World
```
Creates a new world.

Example:
::: code-group

```luau [luau]
local world = jecs.World.new()
```

```ts [typescript]
import { World } from "@rbxts/jecs";

const world = new World();
```

:::

## entity()
```luau
function World:entity(): Entity -- The new entit.
```
Creates a new entity.

Example:
::: code-group

```luau [luau]
local entity = world:entity()
```

```ts [typescript]
const entity = world.entity();
```

:::

### component()
```luau
function World:component<T>(): Entity<T> -- The new componen.
```
Creates a new component.

Example:
::: code-group

```luau [luau]
local Health = world:component() :: jecs.Entity<number>
```

```ts [typescript]
const Health = world.component<number>();
```
:::

::: info
You should use this when creating components.

For example, a Health type should be created using this.
:::

### get()
```luau
function World:get(
    entity: Entity, -- The entity
    ...: Entity<T> -- The types to fetch
): ... -- Returns the component data in the same order they were passed in
```
Returns the data for each provided type for the corresponding entity.

:::

### add()
```luau
function World:add(
    entity: Entity, -- The entity
    id: Entity<T> -- The component ID to add
): ()
```
Adds a component ID to the entity.

This operation adds a single (component) id to an entity.

::: info
This function is idempotent, meaning if the entity already has the id, this operation will have no side effects.
:::


### set()
```luau
function World:set(
    entity: Entity, -- The entity
    id: Entity<T>, -- The component ID to set
    data: T -- The data of the component's type
): ()
```
Adds or changes the entity's component.

### query()
```luau
function World:query(
    ...: Entity -- The IDs to query with
): Query -- Returns the Query
```
Creates a [`query`](query) with the given IDs. Entities that satisfies the conditions of the query will be returned and their corresponding data.

Example:
::: code-group

```luau [luau]
for id, position, velocity in world:query(Position, Velocity) do
	-- Do something
end
```

```ts [typescript]
for (const [id, position, velocity] of world.query(Position, Velocity) {
    // Do something
}
```

:::

:::info
Queries are uncached by default, this is generally very cheap unless you have high fragmentation from e.g. relationships.

:::
### target()
```luau
function World:target(
    entity: Entity, -- The entity
    relation: Entity -- The relationship between the entity and the target
): Entity? -- Returns the parent of the child
```

Get the target of a relationship.

This will return a target (second element of a pair) of the entity for the specified relationship.

If there is no pair with specified relationship, it will return nil.

### parent()
```luau
function World:parent(
    child: Entity -- The child ID to find the parent of
): Entity? -- Returns the parent of the child
```

Get parent (target of ChildOf relationship) for entity. If there is no ChildOf relationship pair, it will return nil.

This operation is the same as calling:

```luau
world:target(entity, jecs.ChildOf)
```
