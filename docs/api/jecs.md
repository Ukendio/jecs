# Jecs

Jecs. Just an Entity Component System.

# Members

## World
```luau
jecs.World: World
```
A world is a container of all ECS data. Games can have multiple worlds but component IDs may conflict between worlds. Ensure to register the same component IDs in the same order for each world.

## Wildcard
```luau
jecs.Wildcard: Id
```
Builtin component type. This ID is used for wildcard queries.

## Component
```luau
jecs.Component: Id
```
Builtin component type. Every ID created with [world:component()](world.md#component()) has this type added to it. This is meant for querying every component ID.

## ChildOf
```luau
jecs.ChildOf: Id
```
Builtin component type. This ID is for creating parent-child hierarchies.

## OnAdd

```luau
jecs.OnAdd: Id
```
Builtin component type. This ID is for setting up a callback that is invoked when an instance of a component is added.

## OnRemove

```luau
jecs.OnRemove: Id
```

Builtin component type. This ID is for setting up a callback that is invoked when an instance of a component is removed.

## OnChange

```luau
jecs.OnChange: Id
```

Builtin component type. This ID is for setting up a callback that is invoked when an instance of a component is changed.

## Exclusive

```lua
jecs.Exclusive: Id
```

Builtin component type. This ID is for encoding that an ID is Exclusive meaning that an entity can never have more than one target for that exclusive relation.

:::code-group
```luau [luau]
local ChildOf = world:entity()
world:add(ChildOf, jecs.Exclusive)

local pop = world:entity()
local dad = world:entity()
local kid = world:entity()

world:add(kid, pair(ChildOf, dad))
print(world:target(kid, ChildOf, 0) == dad)
world:add(kid, pair(ChildOf, pop))
print(world:target(kid, ChildOf, 1) == dad) -- If ChildOf was not exclusive this would have been true
print(world:target(kid, ChildOf, 0) == pop)

-- Output:
--  true
--  false
--  true
```

:::info
By default, jecs.ChildOf is already an exclusive relationship and this is just a demonstration of how to use it.
In some cases you can use Exclusive relationships as a performance optimization as you can guarantee there will only be one target, therefore
retrieving the data from a wildcard pair with that exclusive relationship can be deterministic.
:::

## Name
```luau
jecs.Name: Id
```
Builtin component type. This ID is for naming components, but realistically you could use any component to do that.

## Rest
```luau
jecs.Rest: Id
```

Builtin component type. This ID is for setting up a callback that is invoked when an instance of a component is changed.

# Functions

## pair()
```luau
function jecs.pair(
    first: Entity, -- The first element of the pair, referred to as the relationship of the relationship pair.
    object: Entity, -- The second element of the pair, referred to as the target of the relationship pair.
): number -- Returns the ID with those two elements

```
::: info

While relationship pairs can be used as components and have data associated with an ID, they cannot be used as entities. Meaning you cannot add components to a pair as the source of a binding.

:::

## pair_first()
```luau
function jecs.pair_first(
   	pair: Id, -- A full pair ID encoded using a relation-target pair.
): Entity -- The ID of the first element. Returns 0 if the ID is not alive.
```
Returns the first element (the relation part) of a pair ID.

## pair_second()
```luau
function jecs.pair_second(
   	pair: Id, -- A full pair ID encoded using a relation-target pair.
): Entity -- The ID of the second element. Returns 0 if the ID is not alive.
```
Returns the second element (the target part) of a pair ID.
