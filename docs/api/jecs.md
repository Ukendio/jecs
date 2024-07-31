# Jecs

Jecs. Just an Entity Component System.

## Properties

### World
```luau
jecs.World: World
```
A world is a container of all ECS data. Games can have multiple worlds but component IDs may conflict between worlds. Ensure to register the same component IDs in the same order for each world.

### Wildcard
```luau
jecs.Wildcard: Entity
```
Builtin component type. This ID is used for wildcard queries.

### Component
```luau
jecs.Component: Entity
```
Builtin component type. Every ID created with [world:component()](world.md#component()) has this type added to it. This is meant for querying every component ID.

### ChildOf
```luau
jecs.ChildOf: Entity
```
Builtin component type. This ID is for creating parent-child hierarchies.

:::
### Rest
```luau
jecs.Rest: Entity
```

## Functions

### pair()
```luau
function jecs.pair(
    first: Entity, -- The first element of the pair, referred to as the relationship of the relationship pair.
    object: Entity, -- The second element of the pair, referred to as the target of the relationship pair.
): number -- Returns the Id with those two elements

```
::: info

Note that while relationship pairs can be used as components, meaning you can add data with it as an ID, however they cannot be used as entities. Meaning you cannot add components to a pair as the source of a binding.

:::
