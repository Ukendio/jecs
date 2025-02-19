# Getting Started with Jecs

This guide will help you get Jecs up and running in your project.

## Installation

Choose your preferred installation method:

### Using Wally (Luau)

Add to your wally.toml:
::: code-group
```toml [wally.toml]
[dependencies]
jecs = "ukendio/jecs@0.2.3"
```
:::

Then run:
```bash
wally install
```

### Using npm (roblox-ts)

Use your preferred package manager:
::: code-group
```bash [npm]
npm i https://github.com/Ukendio/jecs.git
```
```bash [yarn]
yarn add https://github.com/Ukendio/jecs.git
```
```bash [pnpm]
pnpm add https://github.com/Ukendio/jecs.git
```
:::

### Standalone Installation

1. Navigate to the [releases page](https://github.com/Ukendio/jecs/releases)
2. Download `jecs.rbxm` from the assets
3. Import into your Roblox project

![jecs.rbxm](rbxm.png)

## Basic Usage

Here's a simple example to get you started:

::: code-group
```lua [luau]
local jecs = require(path.to.jecs)

-- Create a world
local world = jecs.World.new()

-- Define components
local Position = world:component() :: jecs.Entity<Vector3>
local Velocity = world:component() :: jecs.Entity<Vector3>

-- Create an entity
local entity = world:entity()

-- Add components
world:set(entity, Position, Vector3.new(0, 0, 0))
world:set(entity, Velocity, Vector3.new(1, 0, 0))

-- Update system
local function updatePositions()
    for id, position, velocity in world:query(Position, Velocity) do
        world:set(id, Position, position + velocity)
    end
end
```
```typescript [typescript]
import { World } from "@rbxts/jecs";

// Create a world
const world = new World();

// Define components
const Position = world.component<Vector3>();
const Velocity = world.component<Vector3>();

// Create an entity
const entity = world.entity();

// Add components
world.set(entity, Position, new Vector3(0, 0, 0));
world.set(entity, Velocity, new Vector3(1, 0, 0));

// Update system
function updatePositions() {
    for (const [id, position, velocity] of world.query(Position, Velocity)) {
        world.set(id, Position, position.add(velocity));
    }
}
```
:::

## Advanced Example: Relationships

Here's an example showing Jecs' relationship features:

::: code-group
```lua [luau]
local world = jecs.World.new()
local pair = jecs.pair
local Wildcard = jecs.Wildcard

-- Define components
local Name = world:component()
local Eats = world:component()

-- Create food types (components are entities!)
local Apples = world:component()
world:set(Apples, Name, "apples")
local Oranges = world:component()
world:set(Oranges, Name, "oranges")

-- Create entities with relationships
local bob = world:entity()
world:set(bob, Name, "bob")
world:set(bob, pair(Eats, Apples), 10)
world:set(bob, pair(Eats, Oranges), 5)

local alice = world:entity()
world:set(alice, Name, "alice")
world:set(alice, pair(Eats, Apples), 4)

-- Query relationships
for id, amount in world:query(pair(Eats, Wildcard)) do
    local food = world:target(id, Eats)
    print(string.format("%s eats %d %s", 
        world:get(id, Name),
        amount, 
        world:get(food, Name)))
end

-- Output:
--   bob eats 10 apples
--   bob eats 5 oranges
--   alice eats 4 apples
```
:::

## Key Features

### Entity Management
```lua
-- Create entities
local entity = world:entity()

-- Delete entities
world:delete(entity)

-- Clear all components
world:clear(entity)
```

### Component Operations
```lua
-- Add component (tag)
world:add(entity, IsEnemy)

-- Set component value
world:set(entity, Health, 100)

-- Get component value
local health = world:get(entity, Health)

-- Remove component
world:remove(entity, Health)
```

### Relationships
```lua
-- Create parent-child relationship
world:add(child, pair(jecs.ChildOf, parent))

-- Query children
for child in world:query(pair(jecs.ChildOf, parent)) do
    -- Process child entities
end
```

## Next Steps

1. Check out the [First Jecs Project](first-jecs-project.md) tutorial
2. Learn about [Entities and Components](../concepts/entities-and-components.md)
3. Explore [Queries](../concepts/queries.md) and [Relationships](../concepts/relationships.md)
4. Browse the [API Reference](../../api/jecs.md)

## Getting Help

- Join our [Discord server](https://discord.gg/h2NV8PqhAD)
- Check the [FAQ](../faq/common-issues.md)
- Report issues on [GitHub](https://github.com/ukendio/jecs/issues)
