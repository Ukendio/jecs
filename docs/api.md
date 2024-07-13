# API

## World

### World.new() -> `World`
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

### world:entity() -> `Entity<T>`
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

### world:component() -> `Entity<T>`
Creates a new static component. Keep in mind that components are also entities.

Example:
::: code-group

```luau [luau]
local Health = world:component()
```

```ts [typescript]
const Health = world.component<number>();
```

:::

::: info
You should use this when creating static components.

For example, a generic Health entity should be created using this.
:::