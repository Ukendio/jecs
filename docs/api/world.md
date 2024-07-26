# World

A World contains entities which have components. The World is queryable and can be used to get entities with a specific set of components.

## Functions

### new()
```lua
function World.new(): World
```
Creates a new world.

Example:
::: code-group

```luau [luau]
local world = jecs.World.new()
```

```ts [typescript]
import { World } from "@rbxts/jecs";

const world = new World();
```

:::

## entity()
```luau
function World:entity(): Entity
```
Creates a new entity.

Example:
::: code-group

```luau [luau]
local entity = world:entity()
```

```ts [typescript]
const entity = world.entity();
```

:::

### component()`
```luau
function World:component<T>(): Entity<T>
```
Creates a new component.

Example:
::: code-group

```luau [luau]
local Health = world:component() :: jecs.Entity<number>
```

```ts [typescript]
const Health = world.component<number>();
```

:::

::: info
You should use this when creating components.

For example, a Health type should be created using this.
:::
