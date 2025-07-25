# Introduction
Jecs is a standalone entity-component-system module written in Luau.
ECS ("entity-component-system") describes one way to write games in a more data oriented design.

## Installation

Jecs supports the following installation methods using package managers:
:::code-group
```bash [wally]
jecs = "ukendio/jecs@0.6.0" # Inside wally.toml
```
```bash [pesde]
pesde add wally#ukendio/jecs@0.6.0
```
```bash [npm]
npm i @rbxts/jecs
```
:::

Additionally an `rbxm` is published with [each release under the assets submenu](https://github.com/Ukendio/jecs/releases/latest).

## Hello World, Entity and Component
It all has to start somewhere. A world stores entities and their components, and manages them. This tour will reference it for every operation.
:::code-group
```luau [luau]
local jecs = require(path/to/jecs)
local world = jecs.world()
```
```typescript [typescript]
import * as jecs from "@rbxts/jecs"
const world = jecs.world()
// creates a new entity with no components and returns its identifier
const entity = world.entity()

// deletes an entity and all its components
world.delete(entity)
```
:::

## Entities

Entities represent things in a game. In a game there may be entities of characters, buildings, projectiles, particle effects etc.

By itself, an entity is just an unique entity identifier without any data. An entity identifier contains information about the entity itself and its generation.

:::code-group
```luau [luau]
-- creates a new entity with no components and returns its identifier
local entity = world:entity()

-- deletes an entity and all its components
world:delete(entity)
```
```typescript [typescript]
// creates a new entity with no components and returns its identifier
const entity = world.entity()

// deletes an entity and all its components
world.delete(entity)
```
:::

The `entity` member function also accepts an overload that allows you to create an entity with a desired id which bypasses the [`entity range`](#Entity-Ranges).

## Components

A component is something that is added to an entity. Components can simply tag an entity ("this entity is an `Npc`"), attach data to an entity ("this entity is at `Position` `Vector3.new(10, 20, 30)`") and create relationships between entities ("bob `Likes` alice") that may also contain data ("bob `Eats` `10` apples").

## Operations

| Operation | Description                                                                                    |
| --------- | ---------------------------------------------------------------------------------------------- |
| `get`     | Get a specific component or set of components from an entity.                                  |
| `add`     | Adds component to an entity. If entity already has the component, `add` does nothing.          |
| `set`     | Sets the value of a component for an entity. `set` behaves as a combination of `add` and `get` |
| `remove`  | Removes component from entity. If entity doesn't have the component, `remove` does nothing.    |
| `clear`   | Remove all components from an entity. Clearing is more efficient than removing one by one.     |

## Components are entities

In an ECS, components need to be uniquely identified. In Jecs this is done by making each component its own unique entity. This means that everything is customizable. Components are no exception
and all of the APIs that apply to regular entities also apply to component entities.

If a game has a component Position and Velocity, there will be two entities, one for each component. Component entities can be distinguished from "regular" entities as they have a `Component` component trait.

::: code-group
```luau [luau]
local Position = world:component() :: jecs.Entity<Vector3>
world:set(Position, jecs.Name, "Position") -- Using regular apis to set metadata on component entities!

print(`{world:get(Position, jecs.Name)} is a Component: {world:has(Position, jecs.Component)}`);

-- Output:
--  Position is a Component: true
```
```typescript [typescript]
const Position = world.component<Vector3>();
world.set(Position, jecs.Name, "Position") // Using regular apis to set metadata on component entities!

print(`${world.get(Position, jecs.Name)} is a Component: ${world.has(Position, jecs.Component)}`);
// Output:
//  Position is a Component: true
```
:::

### Entity ranges
Jecs reserves entity ids under a threshold (HI_COMPONENT_ID, default is 256) for components. That means that regular entities will start after this number. This number can be further specified via the `range` member function.

::: code-group
```luau [luau]
world:range(1000, 5000) -- Defines the lower and upper bounds of the entity range respectively

local e = world:entity()
print(e)
-- Output:
--  1000
```
```typescript [typescript]
world.range(1000, 5000) // Defines the lower and upper bounds of the entity range respectively

const e = world.entity()
print(e)
// Output:
//  1000
```
:::

### Hooks

Component data generally need to adhere to a specific interface, and sometimes requires side effects to run upon certain lifetime cycles. In `jecs`, there are hooks which are `component traits`, that can define the behaviour of a component and enforce invariants, but can only be invoked through mutations on the component data. You can only configure a single `OnAdd`, `OnRemove` and `OnChange` hook per component, just like you can only have a single constructor and destructor.

::: code-group
```luau [luau]
local Transform = world:component()
world:set(Transform, OnAdd, function(entity, id, data)
    -- A transform component `id` has been added with `data` to `entity`
end)
world:set(Transform, OnRemove, function(entity, id)
    -- A transform component `id` has been removed from `entity`
end)
world:set(Transform, OnChange, function(entity, id, data)
    -- A transform component `id` has been changed to `data` on `entity`
end)
```
```typescript [typescript]
const Transform = world.component();
world.set(Transform, OnAdd, (entity, id, data) => {
	// A transform component `id` has been added with `data` to `entity`
});
world.set(Transform, OnRemove, (entity, id) => {
	// A transform component `id` has been removed from `entity`
});
world.set(Transform, OnChange, (entity, id, data) => {
	// A transform component `id` has been changed to `data` on `entity`
});
```
:::

:::info
Children are cleaned up before parents
When a parent and its children are deleted, OnRemove hooks will be invoked for children first, under the condition that there are no cycles in the relationship graph of the deleted entities. This order is maintained for any relationship that has the (OnDeleteTarget, Delete) trait (see Component Traits for more details).

When an entity graph contains cycles, order is undefined. This includes cycles that can be formed using different relationships.
:::

### Cleanup Traits

When entities that are used as tags, components, relationships or relationship targets are deleted, cleanup traits ensure that the store does not contain any dangling references. Any cleanup policy provides this guarantee, so while they are configurable, games cannot configure traits that allows for dangling references.

We also want to specify this per relationship. If an entity has `(Likes, parent)` we may not want to delete that entity, meaning the cleanup we want to perform for `Likes` and `ChildOf` may not be the same.

This is what cleanup traits are for: to specify which action needs to be executed under which condition. They are applied to entities that have a reference to the entity being deleted: if I delete the `Archer` tag I remove the tag from all entities that have it.

To configure a cleanup policy for an entity, a `(Condition, Action)` pair can be added to it. If no policy is specified, the default cleanup action (`Remove`) is performed.

There are two cleanup actions:

-   `Remove`: removes instances of the specified (component) id from all entities (default)
-   `Delete`: deletes all entities with specified id

There are two cleanup conditions:

-   `OnDelete`: the component, tag or relationship is deleted
-   `OnDeleteTarget`: a target used with the relationship is deleted

#### (OnDelete, Remove)
::: code-group
```luau [luau]
local Archer = world:component()
world:add(Archer, pair(jecs.OnDelete, jecs.Remove))

local e = world:entity()
world:add(e, Archer)

-- This will remove Archer from e
world:delete(Archer)
```
```typescript [typescript]
const Archer = world.component();
world.add(Archer, pair(jecs.OnDelete, jecs.Remove));

const e = world.entity();
world.add(e, Archer);

// This will remove Archer from e
world.delete(Archer);
```
:::

#### (OnDelete, Delete)
::: code-group
```luau [luau]
local Archer = world:component()
world:add(Archer, pair(jecs.OnDelete, jecs.Delete))

local e = world:entity()
world:add(e, Archer)

-- This will delete entity e because the Archer component has a (OnDelete, Delete) cleanup trait
world:delete(Archer)
```
```typescript [typescript]
const Archer = world.component();
world.add(Archer, pair(jecs.OnDelete, jecs.Delete));

const e = world.entity();
world.add(e, Archer);

// This will delete entity e because the Archer component has a (OnDelete, Delete) cleanup trait
world.delete(Archer);
```
:::

#### (OnDeleteTarget, Remove)
::: code-group
```luau [luau]
local OwnedBy = world:component()
world:add(OwnedBy, pair(jecs.OnDeleteTarget, jecs.Remove))
local loot = world:entity()
local player = world:entity()
world:add(loot, pair(OwnedBy, player))

-- This will remove (OwnedBy, player) from loot
world:delete(player)
```
```typescript [typescript]
const OwnedBy = world.component();
world.add(OwnedBy, pair(jecs.OnDeleteTarget, jecs.Remove));
const loot = world.entity();
const player = world.entity();
world.add(loot, pair(OwnedBy, player));

// This will remove (OwnedBy, player) from loot
world.delete(player);
```
:::
#### (OnDeleteTarget, Delete)
::: code-group
```luau [luau]
local ChildOf = world:component()
world:add(ChildOf, pair(jecs.OnDeleteTarget, jecs.Delete))

local parent = world:entity()
local child = world:entity()
world:add(child, pair(ChildOf, parent))

-- This will delete both parent and child
world:delete(parent)
```
```typescript [typescript]
const ChildOf = world.component();
world.add(ChildOf, pair(jecs.OnDeleteTarget, jecs.Delete));

const parent = world.entity();
const child = world.entity();
world.add(child, pair(ChildOf, parent));

// This will delete both parent and child
world.delete(parent);
```
:::

## Preregistration

By default, components being registered on runtime is useful for how dynamic it can be. But, sometimes being able to register components without having the world instance is useful.

::: code-group
```luau [luau]
local Position = jecs.component() :: jecs.Entity<Vector3>

jecs.world() -- Position gets registered here
```

```typescript [typescript]
import { world } from "@rbxts/jecs"
const Position = jecs.component<Vector3>();

world() // Position gets registered here
```
:::

However, if you try to set metadata, you will find that this doesn't work without the world instance. Instead, jecs offers a `meta` member function that can forward declare its metadata.

::: code-group
```luau [luau]
jecs.meta(Position, jecs.Name, "Position")

jecs.world() -- Position gets registered here with its name "Position"
```

```typescript [typescript]
import { world } from "@rbxts/jecs"

jecs.meta(Position, jecs.Name, "Position")

world() // Position gets registered here with its name "Position"
```
:::

### Singletons

Singletons are components for which only a single instance
exists on the world. They can be accessed on the
world directly and do not require providing an entity.
Singletons are useful for global game resources, such as
game state, a handle to a physics engine or a network socket. An example:

::: code-group
```luau [luau]
local TimeOfDay = world:component() :: jecs.Entity<number>
world:set(TimeOfDay, TimeOfDay, 0.5)
local t = world:get(TimeOfDay, TimeOfDay)
```

```typescript [typescript]
const TimeOfDay = world.component<number>();
world.set(TimeOfDay, TimeOfDay, 0.5);
const t = world.get(TimeOfDay, TimeOfDay);
```
:::

# Queries

Queries enable games to quickly find entities that satifies provided conditions.
:::code-group

```luau [luau]
for _ in world:query(Position, Velocity) do end
```

```typescript [typescript]
for (const [_] of world.query(Position, Velocity)) {
}
```
:::

In `jecs`, queries can do anything from returning entities that match a simple list of components, to matching against entity graphs.

This manual contains a full overview of the query features available in Jecs. Some of the features of Jecs queries are:

-   Queries have support for relationships pairs which allow for matching against entity graphs without having to build complex data structures for it.
-   Queries support filters such as [`query:with(...)`](../api/query.md#with) if entities are required to have the components but you don’t actually care about components value. And [`query:without(...)`](../api/query.md#without) which selects entities without the components.
-   Queries can be drained or reset on when called, which lets you choose iterator behaviour.
-   Queries can be called with any ID, including entities created dynamically, this is useful for pairs.
-   Queries are already fast but can be futher inlined via [`query:archetypes()`](../api/query.md#archetypes) for maximum performance to eliminate function call overhead which is roughly 60-80% of the cost for iteration.

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
-   Cached queries add overhead to archetype creation/deletion, as these changes have to get propagated to caches.
-   While caching archetypes is fast, some query features require matching individual entities, which are not efficient to cache (and aren't cached).

As a rule of thumb, if you have a query that is evaluated each frame (as is typically the case with systems), they will benefit from being cached. If you need to create a query ad-hoc, an uncached query makes more sense.

Ad-hoc queries are often necessary when a game needs to find entities that match a condition that is only known at runtime, for example to find all child entities for a specific parent.

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

If you want to iterate multiple targets for the same relation on a pair, then use [`world:target`](../api/world.md#target)

Wildcards are particularly useful when used in combination with pairs (next section).

### Pairs

A pair is an ID that encodes two elements. Pairs, like components, can be added to entities and are the foundation for [`Relationships`](#relationships).

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

## Relationships
Relationships makes it possible to describe entity graphs natively in ECS.

Adding/removing relationships is similar to adding/removing regular components, with as difference that instead of a single component id, a relationship adds a pair of two things to an entity. In this pair, the first element represents the relationship (e.g. "Eats"), and the second element represents the relationship target (e.g. "Apples").

Relationships can be used to describe many things, from hierarchies to inventory systems to trade relationships between players in a game. The following sections go over how to use relationships, and what features they support.

### Definitions

Name      | Description
----------|------------
Id	      | An id that can be added and removed
Component | Id with a single element (same as an entity id)
Relationship | Used to refer to first element of a pair
Target    | Used to refer to second element of a pair
Source    | Entity to which an id is added

### Relationship queries
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
world:has(bob, pair(Eats, jecs.Wildcard))
```
```typescript [typescript]
world.has(bob, pair(Eats, jecs.Wildcard))
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
for (const [id] of world.query(pair(Eats, Apples))) {
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
for (const [id] of world.query(pair(Eats, jecs.Wildcard))) {
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
for (const [child] of world.query(pair(jecs.ChildOf, parent))) {
    // ...
}
```
:::

### Relationship components

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

world:add(e, pair(jecs.ChildOf, Position))

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

world.add(e, pair(jecs.ChildOf, Position))
```
:::

### Relationship wildcards

When querying for relationship pairs, it is often useful to be able to find all instances for a given relationship or target. To accomplish this, an game can use wildcard expressions.

Wildcards may used for the relationship or target part of a pair

```luau
pair(Likes, jecs.Wildcard) -- Matches all Likes relationships
pair(jecs.Wildcard, Alice) -- Matches all relationships with Alice as target
```

### Relationship performance
The ECS storage needs to know two things in order to store components for entities:
- Which IDs are associated with an entity
- Which types are associated with those ids
Ids represent anything that can be added to an entity. An ID that is not associated with a type is called a tag. An ID associated with a type is a component. For regular components, the ID is a regular entity that has the builtin `Component` component.

### Storing relationships
Relationships do not fundamentally change or extend the capabilities of the storage. Relationship pairs are two elements encoded into a single 53-bit ID, which means that on the storage level they are treated the same way as regular component IDs. What changes is the function that determines which type is associated with an id. For regular components this is simply a check on whether an entity has `Component`. To support relationships, new rules are added to determine the type of an id.

Because of this, adding/removing relationships to entities has the same performance as adding/removing regular components. This becomes more obvious when looking more closely at a function that adds a relationship pair.

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
