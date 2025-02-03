# Relationships
Relationships makes it possible to describe entity graphs natively in ECS.

Adding/removing relationships is similar to adding/removing regular components, with as difference that instead of a single component id, a relationship adds a pair of two things to an entity. In this pair, the first element represents the relationship (e.g. "Eats"), and the second element represents the relationship target (e.g. "Apples").

Relationships can be used to describe many things, from hierarchies to inventory systems to trade relationships between players in a game. The following sections go over how to use relationships, and what features they support.

## Definitions

Name      | Description
----------|------------
Id	      | An id that can be added and removed
Component | Id with a single element (same as an entity id)
Relationship | Used to refer to first element of a pair
Target    | Used to refer to second element of a pair
Source    | Entity to which an id is added

## Relationship queries
There are a number of ways a game can query for relationships. The following kinds of queries are available for all (unidirectional) relationships, and are all constant time:

Test if entity has a relationship pair

:::code-group
```luau [luau]
world:has(bob, pair(Eats, Apples))
```
```typescript [typescript]
world.has(bob, pair(Eats, Apples))
```
:::

Test if entity has a relationship wildcard

:::code-group
```luau [luau]
world:has(bob, pair(Eats, jecs.Wildcard)
```
```typescript [typescript]
world.has(bob, pair(Eats, jecs.Wildcard)
```
:::

Get parent for entity

:::code-group
```luau [luau]
world:parent(bob)
```
```typescript [typescript]
world.parent(bob)
```
:::

Find first target of a relationship for entity

:::code-group
```luau [luau]
world:target(bob, Eats)
```
```typescript [typescript]
world.target(bob, Eats)
```
:::

Find all entities with a pair

:::code-group
```luau [luau]
for id in world:query(pair(Eats, Apples)) do
    -- ...
end
```
```typescript [typescript]
for (const [id] of world.query(pair(Eats, Apples)) {
    // ...
}
```
:::

Find all entities with a pair wildcard

:::code-group
```luau [luau]
for id in world:query(pair(Eats, jecs.Wildcard)) do
    local food = world:target(id, Eats) -- Apples, ...
end
```
```typescript [typescript]
for (const [id] of world.query(pair(Eats, jecs.Wildcard)) {
    const food = world.target(id, Eats) // Apples, ...
}
```
:::

Iterate all children for a parent

:::code-group
```luau [luau]
for child in world:query(pair(jecs.ChildOf, parent)) do
    -- ...
end
```
```typescript [typescript]
for (const [child] of world.query(pair(jecs.ChildOf, parent)) {
    // ...
}
```
:::

Relationship components

Relationship pairs, just like regular component, can be associated with data.

:::code-group
```luau [luau]
local Position = world:component()
local Eats = world:component()
local Apples = world:entity()
local Begin = world:entity()
local End = world:entity()

local e = world:entity()
world:set(e, pair(Eats, Apples), { amount = 1 })

world:set(e, pair(Begin, Position), Vector3.new(0, 0, 0))
world:set(e, pair(End, Position), Vector3.new(10, 20, 30))

world:add(e, jecs.ChildOf, Position)

```
```typescript [typescript]
const Position = world.component()
const Eats = world.component()
const Apples = world.entity()
const Begin = world.entity()
const End = world.entity()

const e = world.entity()
world.set(e, pair(Eats, Apples), { amount: 1 })

world.set(e, pair(Begin, Position), new Vector3(0, 0, 0))
world.set(e, pair(End, Position), new Vector3(10, 20, 30))

world.add(e, jecs.ChildOf, Position)
```
:::

## Relationship wildcards

When querying for relationship pairs, it is often useful to be able to find all instances for a given relationship or target. To accomplish this, an game can use wildcard expressions.

Wildcards may used for the relationship or target part of a pair

```luau
pair(Likes, jecs.Wildcard) -- Matches all Likes relationships
pair(jecs.Wildcard, Alice) -- Matches all relationships with Alice as target
```

## Relationship performance
This section goes over the performance implications of using relationships.

### Introduction
The ECS storage needs to know two things in order to store components for entities:
- Which IDs are associated with an entity
- Which types are associated with those ids
Ids represent anything that can be added to an entity. An ID that is not associated with a type is called a tag. An ID associated with a type is a component. For regular components, the ID is a regular entity that has the builtin `Component` component.

### Storing relationships
Relationships do not fundamentally change or extend the capabilities of the storage. Relationship pairs are two elements encoded into a single 53-bit ID, which means that on the storage level they are treated the same way as regular component IDs. What changes is the function that determines which type is associated with an id. For regular components this is simply a check on whether an entity has `Component`. To support relationships, new rules are added to determine the type of an id.

Because of this, adding/removing relationships to entities has the same performance as adding/removing regular components. This becomes more obvious when looking more closely at a function that adds a relationship pair.

### Id ranges
Jecs reserves entity ids under a threshold (HI_COMPONENT_ID, default is 256) for components. This low id range is used by the storage to more efficiently encode graph edges between archetypes. Graph edges for components with low ids use direct array indexing, whereas graph edges for high ids use a hashmap. Graph edges are used to find the next archetype when adding/removing component ids, and are a contributing factor to the performance overhead of add/remove operations.

Because of the way pair IDs are encoded, a pair will never be in the low id range. This means that adding/removing a pair ID always uses a hashmap to find the next archetype. This introduces a small overhead.

### Fragmentation
Fragmentation is a property of archetype-based ECS implementations where entities are spread out over more archetypes as the number of different component combinations increases. The overhead of fragmentation is visible in two areas:
- Archetype creation
- Queries (queries have to match & iterate more archetypes)
Games that make extensive use of relationships might observe high levels of fragmentation, as relationships can introduce many different combinations of components. While the Jecs storage is optimized for supporting large amounts (hundreds of thousands) of archetypes, fragmentation is a factor to consider when using relationships.

Union relationships are planned along with other improvements to decrease the overhead of fragmentation introduced by relationships.

### Archetype Creation

When an ID added to an entity is deleted, all references to that ID are deleted from the storage. For example, when the component Position is deleted it is removed from all entities, and all archetypes with the Position component are deleted. While not unique to relationships, it is more common for relationships to trigger cleanup actions, as relationship pairs contain regular entities.

The opposite is also true. Because relationship pairs can contain regular entities which can be created on the fly, archetype creation is more common than in games that do not use relationships. While Jecs is optimized for fast archetypes creation, creating and cleaning up archetypes is inherently more expensive than creating/deleting an entity. Therefore archetypes creation is a factor to consider, especially for games that make extensive use of relationships.

### Indexing

To improve the speed of evaluating queries, Jecs has indices that store all archetypes for a given component ID. Whenever a new archetype is created, it is registered with the indices for the IDs the archetype has, including IDs for relationship pairs.

While registering an archetype for a relationship index is not more expensive than registering an archetype for a regular index, an archetype with relationships has to also register itself with the appropriate wildcard indices for its relationships. For example, an archetype with relationship `pair(Likes, Apples)` registers itself with the `pair(Likes, Apples)`, `pair(Likes, jecs.Wildcard)` and `pair(jecs.Wildcard, Apples)` indices. For this reason, creating new archetypes with relationships has a higher overhead than an archetype without relationships.

This page takes wording and terminology directly from Flecs, the first ECS with full support for [Entity Relationships](https://www.flecs.dev/flecs/md_docs_2Relationships.html).
