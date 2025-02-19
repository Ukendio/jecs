# Jecs API Reference

Jecs provides a simple but powerful API for entity component systems. This page documents the core API.

## Core Types

### World
```luau
jecs.World: World
```
The main container for all ECS data. See [World API](world.md) for details.

### Entity
```luau
type Entity<T = unknown>
```
A unique identifier that can have components attached. The generic type `T` represents the data type of the entity when used as a component.

### Id
```luau
type Id<T>
```
Represents either an Entity or a Pair that can be used to store component data of type `T`.

## Core Functions

### pair()
```luau
function jecs.pair(
    first: Entity, -- The first element of the pair (relationship)
    object: Entity -- The second element of the pair (target)
): number -- Returns the ID representing this relationship pair
```
Creates a relationship pair between two entities. Used for creating relationships like parent-child, ownership, etc.

::: info
Note that while relationship pairs can be used as components (meaning you can add data with them as an ID), they cannot be used as entities. You cannot add components to a pair as the source of a binding.
:::

Example:
```lua
local ChildOf = world:component()
local parent = world:entity()
local child = world:entity() 

-- Create parent-child relationship
world:add(child, pair(ChildOf, parent))
```

## Constants

### Wildcard
```luau
jecs.Wildcard: Entity
```
Special entity used for querying any entity in a relationship. See [Relationships](../learn/concepts/relationships.md).

### Component
```luau
jecs.Component: Entity
```
Built-in component type. Every component created with `world:component()` has this added to it.

### ChildOf
```luau
jecs.ChildOf: Entity
```
Built-in relationship type for parent-child hierarchies.

### Rest
```luau
jecs.Rest: Entity
```
Special component used in queries to match remaining components.