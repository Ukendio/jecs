# Jecs

Jecs. Just an Entity Component System.

## Properties

### World
```luau
jecs.World: World
```

### Wildcard

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
