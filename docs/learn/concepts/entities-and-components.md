# Entities and Components

## What are Entities?

Entities are the fundamental building blocks in Jecs. An entity represents any object in your game - a character, a building, a projectile, or even abstract concepts like game rules or spawn points.

By itself, an entity is just a unique identifier (a number) without any data. Entities become useful when you add components to them.

## What are Components?

Components are reusable pieces of data that can be attached to entities. They serve three main purposes:

1. **Data Storage**: Hold data for an entity (e.g., Position, Health)
2. **Tagging**: Mark an entity as having certain properties (e.g., IsPlayer, IsEnemy)
3. **Relationships**: Create connections between entities (e.g., ChildOf, Owns)

### Example Components
```lua
-- Data component
local Position = world:component() :: jecs.Entity<Vector3>
local Health = world:component() :: jecs.Entity<number>

-- Tag component
local IsEnemy = world:component()

-- Relationship component
local ChildOf = world:component()
```

## Component Operations

Jecs provides several operations for working with components:

| Operation | Description                                                | Example |
|-----------|------------------------------------------------------------|-|
| `add`     | Adds a component to an entity (no value)                   | `world:add(entity, IsEnemy)` |
| `set`     | Sets a component's value on an entity                      | `world:set(entity, Health, 100)` |
| `get`     | Gets a component's value from an entity                    | `local health = world:get(entity, Health)` |
| `remove`  | Removes a component from an entity                         | `world:remove(entity, IsEnemy)` |
| `clear`   | Removes all components from an entity                      | `world:clear(entity)` |

### Example Usage
::: code-group
```lua [luau]
local world = jecs.World.new()

-- Create components
local Position = world:component() :: jecs.Entity<Vector3>
local Health = world:component() :: jecs.Entity<number>
local IsEnemy = world:component()

-- Create an entity
local enemy = world:entity()

-- Add components and data
world:set(enemy, Position, Vector3.new(0, 0, 0))
world:set(enemy, Health, 100)
world:add(enemy, IsEnemy)

-- Get component data
local pos = world:get(enemy, Position)
print(`Enemy position: {pos}`)

-- Check if entity has component
if world:has(enemy, IsEnemy) then
    print("This is an enemy!")
end
```
```typescript [typescript]
const world = new World();

// Create components
const Position = world.component<Vector3>();
const Health = world.component<number>();
const IsEnemy = world.component();

// Create an entity
const enemy = world.entity();

// Add components and data
world.set(enemy, Position, new Vector3(0, 0, 0));
world.set(enemy, Health, 100);
world.add(enemy, IsEnemy);

// Get component data
const pos = world.get(enemy, Position);
print(`Enemy position: ${pos}`);

// Check if entity has component
if (world.has(enemy, IsEnemy)) {
    print("This is an enemy!");
}
```
:::

## Components are Entities

In Jecs, components themselves are entities with a special `Component` component. This means you can add components to components! This enables powerful features like:

1. Adding metadata to components
2. Creating component hierarchies
3. Defining component relationships

Example:
```lua
local Position = world:component() :: jecs.Entity<Vector3>
local Networked = world:component()
local Type = world:component()

-- Add metadata to Position component
world:add(Position, Networked)
world:set(Position, Type, { size = 12, type = "Vector3" })
```

## Best Practices

1. **Keep Components Simple**
   - Components should store related data
   - Avoid complex nested structures
   - Use multiple components instead of one complex component

2. **Use Tags Effectively**
   - Tags are components without data
   - Great for marking entity states or categories
   - More efficient than components with boolean values

3. **Component Naming**
   - Use clear, descriptive names
   - Consider using noun-based names for data (Position, Health)
   - Consider using adjective-based names for tags (IsEnemy, IsDead)

4. **Data Organization**
   - Group related data in components
   - Split unrelated data into separate components
   - Use relationships for entity connections

## Singletons

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
