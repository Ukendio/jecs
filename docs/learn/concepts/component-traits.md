# Component Traits

Component traits are IDs and pairs that can be added to components to modify their behavior. Although it is possible to create custom traits, this manual only contains an overview of all builtin component traits supported by Jecs.

# Component

Every (component) ID comes with a `Component` which helps with the distinction between normal entities and component IDs.

# Tag

A (component) ID can be marked with `Tag´ in which the component will never contain any data. This allows for zero-cost components which improves performance for structural changes.

# Hooks

Hooks are part of the "interface" of a component. You could consider hooks as the counterpart to OOP methods in ECS. They define the behavior of a component, but can only be invoked through mutations on the component data. You can only configure a single `OnAdd`, `OnRemove` and `OnSet` hook per component, just like you can only have a single constructor and destructor.

## Examples

::: code-group

```luau [luau]
local Transform= world:component()
world:set(Transform, OnAdd, function(entity)
    -- A transform component has been added to an entity
end)
world:set(Transform, OnRemove, function(entity)
    -- A transform component has been removed from the entity
end)
world:set(Transform, OnSet, function(entity, value)
    -- A transform component has been assigned/changed to value on the entity
end)
```

```typescript [typescript]
const Transform = world.component();
world.set(Transform, OnAdd, (entity) => {
	// A transform component has been added to an entity
});
world.set(Transform, OnRemove, (entity) => {
	// A transform component has been removed from the entity
});
world.set(Transform, OnSet, (entity, value) => {
	// A transform component has been assigned/changed to value on the entity
});
```

:::

# Cleanup Traits

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

## Examples

The following examples show how to use cleanup traits

### (OnDelete, Remove)

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

### (OnDelete, Delete)

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

### (OnDeleteTarget, Remove)

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

### (OnDeleteTarget, Delete)

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

This page takes wording and terminology directly from Flecs [documentation](https://www.flecs.dev/flecs/md_docs_2ComponentTraits.html)
