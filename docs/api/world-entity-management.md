# Entity Management

This section covers methods for managing entities in the jecs World.

## delete

Deletes an entity (and its components/relationships) from the world entirely.

```luau
function World:delete(entity: Entity): void
```

### Parameters

| Name | Type | Description |
|------|------|-------------|
| entity | Entity | The entity to delete from the world |

### Behavior

1. Invokes any `OnRemove` hooks for all components on the entity
2. Triggers any cleanup actions based on `OnDelete` and `OnDeleteTarget` relationships
3. Removes the entity from all archetypes
4. Recycles the entity ID for future use

### Example

::: code-group

```luau [luau]
local world = jecs.World.new()

-- Create an entity
local entity = world:entity()
world:set(entity, Position, {x = 0, y = 0})

-- Delete the entity
world:delete(entity)

-- The entity no longer exists in the world
assert(not world:contains(entity))
```

```typescript [typescript]
import { World } from "@rbxts/jecs";

const world = new World();

// Create an entity
const entity = world.entity();
world.set(entity, Position, {x: 0, y: 0});

// Delete the entity
world.delete(entity);

// The entity no longer exists in the world
assert(!world.contains(entity));
```

:::

### Child Entity Deletion

When an entity has children (via the `ChildOf` relationship), deleting the parent can also delete the children if the appropriate cleanup policy is set:

```luau
-- Set up parent-child relationship
local ChildOf = world:component()
world:add(ChildOf, jecs.pair(jecs.OnDeleteTarget, jecs.Delete))

local parent = world:entity()
local child = world:entity()

-- Make child a child of parent
world:add(child, jecs.pair(ChildOf, parent))

-- Deleting parent will also delete child
world:delete(parent)
assert(not world:contains(child))
```

### Component Deletion

The `delete` method can also be used to delete a component definition:

```luau
local Temporary = world:component()
world:add(Temporary, jecs.pair(jecs.OnDelete, jecs.Remove))

-- Add Temporary to entities
local e1 = world:entity()
local e2 = world:entity()
world:add(e1, Temporary)
world:add(e2, Temporary)

-- Delete the component definition
world:delete(Temporary)

-- Temporary is removed from all entities
assert(not world:has(e1, Temporary))
assert(not world:has(e2, Temporary))
```

## remove

Removes a component from a given entity.

```luau
function World:remove(entity: Entity, component: Id): void
```

### Parameters

| Name | Type | Description |
|------|------|-------------|
| entity | Entity | The entity to modify |
| component | Id | The component or relationship to remove |

### Behavior

1. Invokes any `OnRemove` hook for the component being removed
2. Removes the component from the entity
3. May cause the entity to transition to another archetype

### Example

::: code-group

```luau [luau]
local world = jecs.World.new()

-- Create components
local Health = world:component()
local Shield = world:component()

-- Create an entity with both components
local entity = world:entity()
world:set(entity, Health, 100)
world:set(entity, Shield, 50)

-- Remove just the Shield component
world:remove(entity, Shield)

-- Entity still exists but no longer has Shield
assert(world:contains(entity))
assert(world:has(entity, Health))
assert(not world:has(entity, Shield))
```

```typescript [typescript]
import { World } from "@rbxts/jecs";

const world = new World();

// Create components
const Health = world.component();
const Shield = world.component();

// Create an entity with both components
const entity = world.entity();
world.set(entity, Health, 100);
world.set(entity, Shield, 50);

// Remove just the Shield component
world.remove(entity, Shield);

// Entity still exists but no longer has Shield
assert(world.contains(entity));
assert(world.has(entity, Health));
assert(!world.has(entity, Shield));
```

:::

### Removing Relationships

The `remove` method can also be used to remove relationship pairs:

```luau
local ChildOf = world:component()
local parent = world:entity()
local child = world:entity()

-- Establish parent-child relationship
world:add(child, jecs.pair(ChildOf, parent))

-- Remove the relationship
world:remove(child, jecs.pair(ChildOf, parent))

-- Child is no longer related to parent
assert(not world:has(child, jecs.pair(ChildOf, parent)))
```

## Differences Between delete and remove

| Method | What It Affects | Entity Existence | Cleanup Policies |
|--------|-----------------|------------------|------------------|
| delete | Entity and all its components | Entity no longer exists | Triggers all cleanup policies |
| remove | Only the specified component | Entity still exists | Only triggers component-specific OnRemove hook |

### When to Use Each Method

- Use `delete` when you want to completely remove an entity from the world
- Use `remove` when you want to keep the entity but remove specific components
- Use `delete` on a component definition to remove that component from all entities

### Performance Considerations

Both operations may cause archetype transitions, which have performance implications:

- `delete` typically has more overhead because it has to remove all components
- `remove` is generally faster for individual component removal
- Both methods are optimized in jecs to be as efficient as possible

For performance-critical code dealing with many entities, consider batching operations to minimize archetype transitions. 