# First Jecs project

Now that you have installed Jecs, you can create your [World](https://ukendio.github.io/jecs/api/world.html).

:::code-group
```luau [luau]
local jecs = require(path/to/jecs)
local world = jecs.World.new()
```
```typescript [typescript]
import { World } from "@rbxts/jecs"
const world = new World()
```
:::

Let's create a couple components.

:::code-group
```luau [luau]
local jecs = require(path/to/jecs)
local world = jecs.World.new()

local Position = world:component()
local Velocity = world:component()
```

```typescript [typescript]
import { World } from "@rbxts/jecs"
const world = new World()

const Position = world.component()
const Velocity = world.component()
```
:::

Systems can be as simple as a query in a function or a more contextualized construct. Let's make a system that moves an entity and decelerates over time.

:::code-group
```luau [luau]
local jecs = require(path/to/jecs)
local world = jecs.World.new()

local Position = world:component()
local Velocity = world:component()

for id, position, velocity in world:query(Position, Velocity) do
    world:set(id, Position, position + velocity)
    world:set(id, Velocity, velocity * 0.9)
end
```

```typescript [typescript]
import { World } from "@rbxts/jecs"
const world = new World()

const Position = world.component()
const Velocity = world.component()

for (const [id, position, velocity] of world.query(Position, Velocity)) {
    world.set(id, Position, position.add(velocity))
    world.set(id, Velocity, velocity.mul(0.9))
}
```
:::

## Where To Get Help

If you are encountering problems, there are resources for you to get help:
- [Roblox OSS Discord server](https://discord.gg/h2NV8PqhAD) has a [#jecs](https://discord.com/channels/385151591524597761/1248734074940559511) thread under the [#projects](https://discord.com/channels/385151591524597761/1019724676265676930) channel
- [Open an issue](https://github.com/ukendio/jecs/issues) if you run into bugs or have feature requests
- Dive into the nitty gritty in the [thesis paper](https://raw.githubusercontent.com/Ukendio/jecs/main/thesis/drafts/1/paper.pdf)
