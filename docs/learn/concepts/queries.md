# Queries

Queries are the primary way to find and iterate over entities with specific components in Jecs. They provide an efficient way to process only the entities you care about.

## Basic Queries

A basic query finds all entities that have a specific set of components:

::: code-group
```lua [luau]
local Position = world:component() :: jecs.Entity<Vector3>
local Velocity = world:component() :: jecs.Entity<Vector3>

-- Find all entities with both Position and Velocity
for id, position, velocity in world:query(Position, Velocity) do
    -- Update position based on velocity
    world:set(id, Position, position + velocity)
end
```
```typescript [typescript]
const Position = world.component<Vector3>();
const Velocity = world.component<Vector3>();

// Find all entities with both Position and Velocity
for (const [id, position, velocity] of world.query(Position, Velocity)) {
    // Update position based on velocity
    world.set(id, Position, position.add(velocity));
}
```
:::

## Query Filters

Queries can be refined using filters to be more specific about what entities you want:

### with()
Find entities that have additional components, but don't need their values:

```lua
-- Find entities with Position that also have IsEnemy
for id, position in world:query(Position):with(IsEnemy) do
    -- Process enemy positions
end
```

### without()
Exclude entities that have specific components:

```lua
-- Find entities with Position that don't have IsDestroyed
for id, position in world:query(Position):without(IsDestroyed) do
    -- Process active entities
end
```

## Query Performance

Queries in Jecs are optimized for performance:

1. **Archetype-based**: Entities are grouped by their component combinations
2. **Cache-friendly**: Components are stored in contiguous memory
3. **Zero Allocation**: Iteration doesn't allocate memory

### Query Caching

For frequently used queries, you can cache them to avoid rebuilding the query:

```lua
-- Cache a commonly used query
local movementQuery = world:query(Position, Velocity):cached()

-- Use the cached query
for id, position, velocity in movementQuery:iter() do
    -- Process movement
end
```

## Advanced Query Features

### Relationship Queries
Query entities based on their relationships:

```lua
local ChildOf = world:component()

-- Find all children of a parent
for child in world:query(pair(ChildOf, parent)) do
    -- Process child entities
end

-- Find entities with any parent
for child in world:query(pair(ChildOf, jecs.Wildcard)) do
    local parent = world:target(child, ChildOf)
    -- Process parent-child relationship
end
```

### Component Trait Queries
Find components with specific traits:

```lua
-- Find all networked components
for component in world:query(jecs.Component):with(Networked) do
    -- Process networked components
end
```

## Best Practices

1. **Query Organization**
   - Keep queries focused on related components
   - Cache frequently used queries
   - Consider splitting complex queries into simpler ones

2. **Performance Optimization**
   - Use `with()` for components you don't need values from
   - Consider component order (most restrictive first)
   - Cache queries used in hot paths

3. **Query Design**
   - Query only the components you need
   - Use relationships for hierarchical queries
   - Consider using tags for efficient filtering

4. **Common Patterns**
   ```lua
   -- Movement system
   for id, pos, vel in world:query(Position, Velocity):without(Frozen) do
       world:set(id, Position, pos + vel)
   end

   -- Damage system
   for id, health in world:query(Health):with(TakingDamage) do
       if health <= 0 then
           world:add(id, IsDead)
       end
   end

   -- Cleanup system
   for id in world:query(IsDead) do
       world:delete(id)
   end
   ```

## Introductiuon

Queries enable games to quickly find entities that satifies provided conditions.

Jecs queries can do anything from returning entities that match a simple list of components, to matching against entity graphs.

This manual contains a full overview of the query features available in Jecs. Some of the features of Jecs queries are:

-   Queries have support for relationships pairs which allow for matching against entity graphs without having to build complex data structures for it.
-   Queries support filters such as [`query:with(...)`](../../api/query.md#with) if entities are required to have the components but you don't actually care about components value. And [`query:without(...)`](../../api/query.md#without) which selects entities without the components.
-   Queries can be drained or reset on when called, which lets you choose iterator behaviour.
-   Queries can be called with any ID, including entities created dynamically, this is useful for pairs.
-   Queries are already fast but can be futher inlined via [`query:archetypes()`](../../api/query.md#archetypes) for maximum performance to eliminate function call overhead which is roughly 70-80% of the cost for iteration.

## Performance and Caching

Understanding the basic architecture of queries helps to make the right tradeoffs when using queries in games.
The biggest impact on query performance is whether a query is cached or not.
This section goes over what caching is, how it can be used and when it makes sense to use it.

### Caching: what is it?

Jecs is an archetype ECS, which means that entities with exactly the same components are
grouped together in an "archetype". Archetypes are created on the fly
whenever a new component combination is created in the ECS. For example:

:::code-group

```luau [luau]
local e1 = world:entity()
world:set(e1, Position, Vector3.new(10, 20, 30)) -- create archetype [Position]
world:set(e1, Velocity, Vector3.new(1, 2, 3))    -- create archetype [Position, Velocity]

local e2 = world:entity()
world:set(e2, Position, Vector3.new(10, 20, 30)) -- archetype [Position] already exists
world:set(e2, Velocity, Vector3.new(1, 2, 3)) 	 -- archetype [Position, Velocity] already exists
world:set(e3, Mass, 100) 						 -- create archetype [Position, Velocity, Mass]

-- e1 is now in archetype [Position, Velocity]
-- e2 is now in archetype [Position, Velocity, Mass]
```

```typescript [typescript]
const e1 = world.entity();
world.set(e1, Position, new Vector3(10, 20, 30)); // create archetype [Position]
world.set(e1, Velocity, new Vector3(1, 2, 3)); // create archetype [Position, Velocity]

const e2 = world.entity();
world.set(e2, Position, new Vector3(10, 20, 30)); // archetype [Position] already exists
world.set(e2, Velocity, new Vector3(1, 2, 3)); // archetype [Position, Velocity] already exists
world.set(e3, Mass, 100); // create archetype [Position, Velocity, Mass]

// e1 is now in archetype [Position, Velocity]
// e2 is now in archetype [Position, Velocity, Mass]
```

:::

Archetypes are important for queries. Since all entities in an archetype have the same components, and a query matches entities with specific components, a query can often match entire archetypes instead of individual entities. This is one of the main reasons why queries in an archetype ECS are fast.

The second reason that queries in an archetype ECS are fast is that they are cheap to cache. While an archetype is created for each unique component combination, games typically only use a finite set of component combinations which are created quickly after game assets are loaded.

This means that instead of searching for archetypes each time a query is evaluated, a query can instead cache the list of matching archetypes. This is a cheap cache to maintain: even though entities can move in and out of archetypes, the archetypes themselves are often stable.

If none of that made sense, the main thing to remember is that a cached query does not actually have to search for entities. Iterating a cached query just means iterating a list of prematched results, and this is really, really fast.

### Tradeoffs

Jecs has both cached and uncached queries. If cached queries are so fast, why even bother with uncached queries? There are four main reasons:

-   Cached queries are really fast to iterate, but take more time to create because the cache must be initialized first.
-   Cached queries have a higher RAM utilization, whereas uncached queries have very little overhead and are stateless.
-   Cached queries add overhead to archetype creation/deletion, as these changes have to get propagated to caches.
-   While caching archetypes is fast, some query features require matching individual entities, which are not efficient to cache (and aren't cached).

As a rule of thumb, if you have a query that is evaluated each frame (as is typically the case with systems), they will benefit from being cached. If you need to create a query ad-hoc, an uncached query makes more sense.

Ad-hoc queries are often necessary when a game needs to find entities that match a condition that is only known at runtime, for example to find all child entities for a specific parent.

## Creating Queries

This section explains how to create queries in the different language bindings.

:::code-group

```luau [luau]
for _ in world:query(Position, Velocity) do end
```

```typescript [typescript]
for (const [_] of world.query(Position, Velocity)) {
}
```

:::

### Components

A component is any single ID that can be added to an entity. This includes tags and regular entities, which are IDs that do not have the builtin `Component` component. To match a query, an entity must have all the requested components. An example:

```luau
local e1 = world:entity()
world:add(e1, Position)

local e2 = world:entity()
world:add(e2, Position)
world:add(e2, Velocity)

local e3 = world:entity()
world:add(e3, Position)
world:add(e3, Velocity)
world:add(e3, Mass)

```

Only entities `e2` and `e3` match the query Position, Velocity.

### Wildcards

Jecs currently only supports the `Any` type of wildcards which a single result for the first component that it matches.

When using the `Any` type wildcard it is undefined which component will be matched, as this can be influenced by other parts of the query. It is guaranteed that iterating the same query twice on the same dataset will produce the same result.

If you want to iterate multiple targets for the same relation on a pair, then use [`world:target`](../../api/world.md#target)

Wildcards are particularly useful when used in combination with pairs (next section).

### Pairs

A pair is an ID that encodes two elements. Pairs, like components, can be added to entities and are the foundation for [Relationships](relationships.md).

The elements of a pair are allowed to be wildcards. When a query pair returns an `Any` type wildcard, the query returns at most a single matching pair on an entity.

The following sections describe how to create queries for pairs in the different language bindings.

:::code-group

```luau [luau]
local Likes = world:entity()
local bob = world:entity()
for _ in world:query(pair(Likes, bob)) do end
```

```typescript [typescript]
const Likes = world.entity();
const bob = world.entity();
for (const [_] of world.query(pair(Likes, bob))) {
}
```

:::

When a query pair contains a wildcard, the `world:target()` function can be used to determine the target of the pair element that matched the query:

:::code-group

```luau [luau]
for id in world:query(pair(Likes, jecs.Wildcard)) do
    print(`entity {getName(id)} likes {getName(world, world:target(id, Likes))}`)
end
```

```typescript [typescript]
const Likes = world.entity();
const bob = world.entity();
for (const [_] of world.query(pair(Likes, jecs.Wildcard))) {
	print(`entity ${getName(id)} likes ${getName(world.target(id, Likes))}`);
}
```

:::

### Filters

Filters are extensions to queries which allow you to select entities from a more complex pattern but you don't actually care about the component values.

The following filters are supported by queries:

| Identifier | Description                         |
| ---------- | ----------------------------------- |
| With       | Must match with all terms.          |
| Without    | Must not match with provided terms. |

This page takes wording and terminology directly from Flecs [documentation](https://www.flecs.dev/flecs/md_docs_2Queries.html)
