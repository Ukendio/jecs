# Queries

## Introductiuon

Queries enable games to quickly find entities that satifies provided conditions.

Jecs queries can do anything from returning entities that match a simple list of components, to matching against entity graphs.

This manual contains a full overview of the query features available in Jecs. Some of the features of Jecs queries are:

- Queries have support for relationships pairs which allow for matching against entity graphs without having to build complex data structures for it.
- Queries support filters such as `query:with(...)` if entities are required to have the components but you don’t actually care about components value. And `query:without(...)` which selects entities without the components.
- Queries can be drained or reset on when called, which lets you choose iterator behaviour.
- Queries can be called with any ID, including entities created dynamically, this is useful for pairs.
- Queries are already fast but can be futher inlined via `query:archetypes()` for maximum performance to eliminate function call overhead which is roughly 70-80% of the cost for iteration.

## Creating Queries
This section explains how to create queries in the different language bindings.

:::code-group
```luau [luau]
for _ in world:query(Position, Velocity) do end
```
```typescript [typescript]
for (const [_] of world.query(Position, Velocity)) {}
```

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
const Likes = world.entity()
const bob = world.entity()
for (const [_] of world.query(pair(Likes, bob))) {}
```

When a query pair contains a wildcard, the `world:target()` function can be used to determine the target of the pair element that matched the query:

:::code-group
```luau [luau]
for id in world:query(pair(Likes, jecs.Wildcard)) do
    print(`entity {getName(id)} likes {getName(world, world:target(id, Likes))}`)
end
```
```typescript [typescript]
const Likes = world.entity()
const bob = world.entity()
for (const [_] of world.query(pair(Likes, jecs.Wildcard))) {
    print(`entity ${getName(id)} likes ${getName(world.target(id, Likes))}`)
}
```

### Filters
Filters are extensions to queries which allow you to select entities from a more complex pattern but you don't actually care about the component values.

The following filters are supported by queries:

Identifier | Description
---------- | -----------
With       | Must match with all terms.
Without    | Must not match with provided terms.

This page takes wording and terminology directly from Flecs [documentation](https://www.flecs.dev/flecs/md_docs_2Queries.html)
