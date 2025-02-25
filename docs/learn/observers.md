# Observer APIs

jecs provides observer hooks that allow you to respond to component lifecycle events and implement cleanup policies.

## Component Lifecycle Hooks

Component lifecycle hooks let you execute code when components are added, removed, or modified.

### OnAdd

The `OnAdd` hook is called when a component is added to an entity.

```lua
-- Define a component
local Transform = world:component()

-- Set an OnAdd hook for the Transform component
world:set(Transform, jecs.OnAdd, function(entity)
  print("Transform component added to entity", entity)
end)

-- The hook will be called when Transform is added to any entity
local entity = world:entity()
world:add(entity, Transform) -- OnAdd hook is triggered
```

TypeScript signature:
```typescript
type OnAddHook = (entity: Entity) => void;
```

### OnRemove

The `OnRemove` hook is called when a component is removed from an entity.

```lua
-- Set an OnRemove hook for the Transform component
world:set(Transform, jecs.OnRemove, function(entity)
  print("Transform component removed from entity", entity)
end)

-- The hook will be called when Transform is removed from any entity
world:remove(entity, Transform) -- OnRemove hook is triggered
```

TypeScript signature:
```typescript
type OnRemoveHook = (entity: Entity) => void;
```

### OnSet

The `OnSet` hook is called when a component's value is set or changed on an entity.

```lua
-- Set an OnSet hook for the Transform component
world:set(Transform, jecs.OnSet, function(entity, value)
  print("Transform component set on entity", entity, "with value", value)
end)

-- The hook will be called when Transform's value is set on any entity
world:set(entity, Transform, { position = {x = 10, y = 20} }) -- OnSet hook is triggered
```

TypeScript signature:
```typescript
type OnSetHook<T> = (entity: Entity, value: T) => void;
```

## Automatic Cleanup Policies

jecs provides automatic cleanup policies through the `OnDelete` and `OnDeleteTarget` hooks paired with action components.

### OnDelete

The `OnDelete` trait specifies what happens when a component or entity is deleted. It must be paired with an action component like `Delete` or `Remove`.

#### (OnDelete, Delete)

When paired with `Delete`, this policy deletes entities that have the component when the component itself is deleted.

```lua
-- Define a component
local Health = world:component()

-- Add the (OnDelete, Delete) cleanup policy to Health
world:add(Health, jecs.pair(jecs.OnDelete, jecs.Delete))

-- Create entities
local entity1 = world:entity()
local entity2 = world:entity()

-- Add Health component to entities
world:add(entity1, Health)
world:add(entity2, Health)

-- When Health component is deleted, all entities with Health will be deleted
world:delete(Health) -- Deletes entity1 and entity2
```

#### (OnDelete, Remove)

When paired with `Remove`, this policy removes a component from entities when the component itself is deleted.

```lua
-- Define components
local Poison = world:component()
local PoisonEffect = world:component()

-- Add the (OnDelete, Remove) cleanup policy to Poison
world:add(Poison, jecs.pair(jecs.OnDelete, jecs.Remove))
world:add(PoisonEffect, jecs.pair(jecs.OnDelete, jecs.Remove))

-- Create entity
local entity = world:entity()
world:add(entity, Poison)
world:add(entity, PoisonEffect)

-- When Poison component is deleted, PoisonEffect will be removed from all entities
world:delete(Poison) -- Removes PoisonEffect from entity
```

### OnDeleteTarget

The `OnDeleteTarget` trait specifies what happens when a relationship target is deleted. It must be paired with an action component like `Delete` or `Remove`.

#### (OnDeleteTarget, Delete)

When paired with `Delete`, this policy deletes entities that have a relationship with the deleted target.

```lua
-- Define a ChildOf component for parent-child relationships
local ChildOf = world:component()

-- Add the (OnDeleteTarget, Delete) cleanup policy
world:add(ChildOf, jecs.pair(jecs.OnDeleteTarget, jecs.Delete))

-- Create parent and child entities
local parent = world:entity()
local child1 = world:entity()
local child2 = world:entity()

-- Establish parent-child relationships
world:add(child1, jecs.pair(ChildOf, parent))
world:add(child2, jecs.pair(ChildOf, parent))

-- When the parent is deleted, all its children will be deleted too
world:delete(parent) -- Deletes child1 and child2
```

#### (OnDeleteTarget, Remove)

When paired with `Remove`, this policy removes a relationship component when its target is deleted.

```lua
-- Define a Likes component for relationships
local Likes = world:component()

-- Add the (OnDeleteTarget, Remove) cleanup policy
world:add(Likes, jecs.pair(jecs.OnDeleteTarget, jecs.Remove))

-- Create entities
local bob = world:entity()
local alice = world:entity()
local charlie = world:entity()

-- Establish relationships
world:add(bob, jecs.pair(Likes, alice))
world:add(charlie, jecs.pair(Likes, alice))

-- When alice is deleted, all Likes relationships targeting her will be removed
world:delete(alice) -- Removes Likes relationship from bob and charlie
```

## Best Practices

1. **Use hooks for reactive logic**: Component hooks are perfect for synchronizing game state with visual representations or external systems.

2. **Keep hook logic simple**: Hooks should be lightweight and focused on a single concern.

3. **Consider cleanup policies carefully**: The right cleanup policies can prevent memory leaks and simplify your codebase by automating entity management.

4. **Avoid infinite loops**: Be careful not to create circular dependencies with your hooks and cleanup policies.

5. **Document your policies**: When using cleanup policies, document them clearly so other developers understand the entity lifecycle in your application.

6. **Use OnAdd for initialization**: The OnAdd hook is ideal for initializing component-specific resources.

7. **Use OnRemove for cleanup**: The OnRemove hook ensures resources are properly released when components are removed.

8. **Use OnSet for synchronization**: The OnSet hook helps keep different aspects of your game in sync when component values change.

## Example: Complete Entity Lifecycle

This example shows how to use all observer hooks together to manage an entity's lifecycle:

```lua
local world = jecs.World.new()
local pair = jecs.pair

-- Define components
local Model = world:component()
local Transform = world:component()
local ChildOf = world:component()

-- Set up component hooks
world:set(Model, jecs.OnAdd, function(entity)
    print("Model added to entity", entity)
    -- Create visual representation
end)

world:set(Model, jecs.OnRemove, function(entity)
    print("Model removed from entity", entity)
    -- Destroy visual representation
end)

world:set(Model, jecs.OnSet, function(entity, model)
    print("Model set on entity", entity, "with value", model)
    -- Update visual representation
end)

-- Set up cleanup policies
world:add(ChildOf, pair(jecs.OnDeleteTarget, jecs.Delete))
world:add(Transform, pair(jecs.OnDelete, jecs.Remove))

-- Create entities
local parent = world:entity()
local child = world:entity()

-- Set up relationships and components
world:add(child, pair(ChildOf, parent))
world:set(child, Model, "cube")
world:set(child, Transform, {position = {x = 0, y = 0, z = 0}})

-- Updating a component triggers the OnSet hook
world:set(child, Model, "sphere")

-- Removing a component triggers the OnRemove hook
world:remove(child, Model)

-- Deleting the parent triggers the OnDeleteTarget cleanup policy
-- which automatically deletes the child
world:delete(parent)
```

By effectively using observer hooks and cleanup policies, you can create more maintainable and robust ECS-based applications with less manual resource management. 