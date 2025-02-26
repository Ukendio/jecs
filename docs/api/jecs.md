# Jecs

Jecs. Just an Entity Component System.

# Properties

## World
```luau
jecs.World: World
```
A world is a container of all ECS data. Games can have multiple worlds but component IDs may conflict between worlds. Ensure to register the same component IDs in the same order for each world.

## Wildcard
```luau
jecs.Wildcard: Entity
```
Builtin component type. This ID is used for wildcard queries.

## w
```luau
jecs.w: Entity
```
An alias for `jecs.Wildcard`. This ID is used for wildcard queries, providing a shorter syntax in query operations.

## Component
```luau
jecs.Component: Entity
```
Builtin component type. Every ID created with [world:component()](world.md#component()) has this type added to it. This is meant for querying every component ID.

## ChildOf
```luau
jecs.ChildOf: Entity
```
Builtin component type. This ID is for creating parent-child hierarchies.

## Name
```luau
jecs.Name: Entity
```
Builtin component type. This ID is used to associate a string name with an entity, typically for debugging or display purposes.

## OnAdd
```luau
jecs.OnAdd: Entity<(entity: Entity) -> ()>
```
Builtin component hook. When set on a component, the provided function is called whenever that component is added to an entity.

## OnRemove
```luau
jecs.OnRemove: Entity<(entity: Entity) -> ()>
```
Builtin component hook. When set on a component, the provided function is called whenever that component is removed from an entity.

## OnSet
```luau
jecs.OnSet: Entity<(entity: Entity, data: any) -> ()>
```
Builtin component hook. When set on a component, the provided function is called whenever that component's value is set or changed on an entity.

## OnDelete
```luau
jecs.OnDelete: Entity
```
Builtin component trait. Used with `pair()` to define behavior when a component or entity is deleted. Must be paired with an action component like `jecs.Delete` or `jecs.Remove`.

## OnDeleteTarget
```luau
jecs.OnDeleteTarget: Entity
```
Builtin component trait. Used with `pair()` to define behavior when a relationship target is deleted. Must be paired with an action component like `jecs.Delete` or `jecs.Remove`.

## Delete
```luau
jecs.Delete: Entity
```
Builtin action component used with `OnDelete` or `OnDeleteTarget` to specify that entities should be deleted in the cleanup process.

## Remove
```luau
jecs.Remove: Entity
```
Builtin action component used with `OnDelete` or `OnDeleteTarget` to specify that components should be removed in the cleanup process.

## Rest
```luau
jecs.Rest: Entity
```

# Functions

## pair()
```luau
function jecs.pair(
    first: Entity, -- The first element of the pair, referred to as the relationship of the relationship pair.
    object: Entity, -- The second element of the pair, referred to as the target of the relationship pair.
): number -- Returns the ID with those two elements

```
::: info

Note that while relationship pairs can be used as components, meaning you can add data with it as an ID, however they cannot be used as entities. Meaning you cannot add components to a pair as the source of a binding.

:::
