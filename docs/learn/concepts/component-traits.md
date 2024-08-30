# Component Traits

Component traits are ID and pairs that can be added to components to modify their behavior. This manual contains an overview of all component traits supported by Jecs.

# Cleanup Traits

When entities that are used as tags, components, relationships or relationship targets are deleted, cleanup traits ensure that the store does not contain any dangling references. Any cleanup policy provides this guarantee, so while they are configurable, games cannot configure traits that allows for dangling references.

We also want to specify this per relationship. If an entity has `(Likes, parent)` we may not want to delete that entity, meaning the cleanup we want to perform for `Likes` and `ChildOf` may not be the same.

This is what cleanup traits are for: to specify which action needs to be executed under which condition. They are applied to entities that have a reference to the entity being deleted: if I delete the `Archer` tag I remove the tag from all entities that have it.

To configure a cleanup policy for an entity, a `(Condition, Action)` pair can be added to it. If no policy is specified, the default cleanup action (`Remove`) is performed.

There are two cleanup actions:

- `Remove`: removes instances of the specified (component) id from all entities (default)
- `Delete`: deletes all entities with specified id

There are two cleanup conditions:

- `OnDelete`: the component, tag or relationship is deleted
- `OnDeleteTarget`: a target used with the relationship is deleted

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
const Archer = world.component()
world.add(Archer, pair(jecs.OnDelete, jecs.Remove))

const e = world:entity()
world.add(e, Archer)

// This will remove Archer from e
world.delete(Archer)
```

:::

### (OnDelete, Delete)
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
const Archer = world.component()
world.add(Archer, pair(jecs.OnDelete, jecs.Remove))

const e = world:entity()
world.add(e, Archer)

// This will remove Archer from e
world.delete(Archer)
```

:::

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
const Archer = world.component()
world.add(Archer, pair(jecs.OnDelete, jecs.Remove))

const e = world:entity()
world.add(e, Archer)

// This will delete e
world.delete(Archer)
```

:::

This page takes wording and terminology directly from Flecs [documentation](https://www.flecs.dev/flecs/md_docs_2ComponentTraits.html)
