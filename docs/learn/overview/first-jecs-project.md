# Your First Jecs Project

This tutorial will walk you through creating your first project with Jecs, demonstrating core concepts and best practices.

## Setting Up

First, make sure you have Jecs installed. If not, check the [Getting Started](get-started.md) guide.

::: code-group
```lua [luau]
local jecs = require(path.to.jecs)
local world = jecs.World.new()
```
```typescript [typescript]
import { World } from "@rbxts/jecs";
const world = new World();
```
:::

## Creating Components

Let's create some basic components for a simple game:

::: code-group
```lua [luau]
-- Position in 3D space
local Position = world:component() :: jecs.Entity<Vector3>

-- Velocity for movement
local Velocity = world:component() :: jecs.Entity<Vector3>

-- Health for gameplay
local Health = world:component() :: jecs.Entity<number>

-- Tag for marking enemies
local IsEnemy = world:component()
```
```typescript [typescript]
// Position in 3D space
const Position = world.component<Vector3>();

// Velocity for movement
const Velocity = world.component<Vector3>();

// Health for gameplay
const Health = world.component<number>();

// Tag for marking enemies
const IsEnemy = world.component();
```
:::

## Creating Game Systems

Let's create some basic systems to handle movement and gameplay:

### Movement System
::: code-group
```lua [luau]
-- Cache the query for better performance
local movementQuery = world:query(Position, Velocity):cached()

local function updateMovement(deltaTime)
    for id, position, velocity in movementQuery:iter() do
        -- Update position based on velocity and time
        world:set(id, Position, position + velocity * deltaTime)
    end
end
```
```typescript [typescript]
// Cache the query for better performance
const movementQuery = world.query(Position, Velocity).cached();

function updateMovement(deltaTime: number) {
    for (const [id, position, velocity] of movementQuery) {
        // Update position based on velocity and time
        world.set(id, Position, position.add(velocity.mul(deltaTime)));
    }
}
```
:::

### Damage System
::: code-group
```lua [luau]
local function applyDamage(entity, amount)
    local currentHealth = world:get(entity, Health)
    if currentHealth then
        local newHealth = currentHealth - amount
        if newHealth <= 0 then
            world:delete(entity)
        else
            world:set(entity, Health, newHealth)
        end
    end
end
```
```typescript [typescript]
function applyDamage(entity: Entity, amount: number) {
    const currentHealth = world.get(entity, Health);
    if (currentHealth) {
        const newHealth = currentHealth - amount;
        if (newHealth <= 0) {
            world.delete(entity);
        } else {
            world.set(entity, Health, newHealth);
        }
    }
}
```
:::

## Creating Game Entities

Now let's create some game entities:

::: code-group
```lua [luau]
-- Create a player
local player = world:entity()
world:set(player, Position, Vector3.new(0, 0, 0))
world:set(player, Velocity, Vector3.new(0, 0, 0))
world:set(player, Health, 100)

-- Create an enemy
local enemy = world:entity()
world:set(enemy, Position, Vector3.new(10, 0, 10))
world:set(enemy, Health, 50)
world:add(enemy, IsEnemy)
```
```typescript [typescript]
// Create a player
const player = world.entity();
world.set(player, Position, new Vector3(0, 0, 0));
world.set(player, Velocity, new Vector3(0, 0, 0));
world.set(player, Health, 100);

// Create an enemy
const enemy = world.entity();
world.set(enemy, Position, new Vector3(10, 0, 10));
world.set(enemy, Health, 50);
world.add(enemy, IsEnemy);
```
:::

## Adding Relationships

Let's add some parent-child relationships:

::: code-group
```lua [luau]
-- Create weapon entity
local weapon = world:entity()
world:add(weapon, pair(jecs.ChildOf, player))

-- Query for player's children
for child in world:query(pair(jecs.ChildOf, player)) do
    print("Found player's child:", child)
end
```
```typescript [typescript]
// Create weapon entity
const weapon = world.entity();
world.add(weapon, pair(jecs.ChildOf, player));

// Query for player's children
for (const [child] of world.query(pair(jecs.ChildOf, player))) {
    print("Found player's child:", child);
}
```
:::

## Running the Game Loop

Here's how to put it all together:

::: code-group
```lua [luau]
local RunService = game:GetService("RunService")

RunService.Heartbeat:Connect(function(deltaTime)
    -- Update movement
    updateMovement(deltaTime)
    
    -- Other game systems...
end)
```
```typescript [typescript]
const RunService = game.GetService("RunService");

RunService.Heartbeat.Connect((deltaTime) => {
    // Update movement
    updateMovement(deltaTime);
    
    // Other game systems...
});
```
:::

## Next Steps

1. Learn more about [Entities and Components](../concepts/entities-and-components.md)
2. Explore [Queries](../concepts/queries.md) in depth
3. Understand [Relationships](../concepts/relationships.md)
4. Check out [Component Traits](../concepts/component-traits.md)
5. Browse the [API Reference](../../api/jecs.md)

## Where To Get Help

If you are encountering problems, there are resources for you to get help:
- [Roblox OSS Discord server](https://discord.gg/h2NV8PqhAD) has a [#jecs](https://discord.com/channels/385151591524597761/1248734074940559511) thread under the [#projects](https://discord.com/channels/385151591524597761/1019724676265676930) channel
- [Open an issue](https://github.com/ukendio/jecs/issues) if you run into bugs or have feature requests
- Dive into the nitty gritty in the [thesis paper](https://raw.githubusercontent.com/Ukendio/jecs/main/thesis/drafts/1/paper.pdf)
