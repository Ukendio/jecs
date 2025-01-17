# Entities and Components

## Entities

Entities represent things in a game. In a game there may be entities of characters, buildings, projectiles, particle effects etc.

By itself, an entity is just an unique identifier without any data

## Components

A component is something that is added to an entity. Components can simply tag an entity ("this entity is an `Npc`"), attach data to an entity ("this entity is at `Position` `Vector3.new(10, 20, 30)`") and create relationships between entities ("bob `Likes` alice") that may also contain data ("bob `Eats` `10` apples").

## Operations

| Operation | Description                                                                                    |
| --------- | ---------------------------------------------------------------------------------------------- |
| `get`     | Get a specific component or set of components from an entity.                                  |
| `add`     | Adds component to an entity. If entity already has the component, `add` does nothing.          |
| `set`     | Sets the value of a component for an entity. `set` behaves as a combination of `add` and `get` |
| `remove`  | Removes component from entity. If entity doesn't have the component, `remove` does nothing.    |
| `clear`   | Remove all components from an entity. Clearing is more efficient than removing one by one.     |

## Components are entities

In an ECS, components need to be uniquely identified. In Jecs this is done by making each component its own unique entity. If a game has a component Position and Velocity, there will be two entities, one for each component. Component entities can be distinguished from "regular" entities as they have a `Component` component. An example:

::: code-group

```luau [luau]
local Position = world:component() :: jecs.Entity<Vector3>
print(world:has(Position, jecs.Component))
```

```typescript [typescript]
const Position = world.component<Vector3>();
print(world.has(Position, jecs.Component));
```

:::

All of the APIs that apply to regular entities also apply to component entities. This means it is possible to contexualize components with logic by adding traits to components

::: code-group

```luau [luau]
local Networked = world:component()
local Type = world:component()
local Name = world:component()
local Position = world:component() :: jecs.Entity<Vector3>
world:add(Position, Networked)
world:set(Position, Name, "Position")
world:set(Position, Type, { size = 12, type = "Vector3" } ) -- 12 bytes to represent a Vector3

for id, ty, name in world:query(Type, Name, Networked) do
    local batch = {}
    for entity, data in world:query(id) do
        table.insert(batch, { entity = entity, data = data })
    end
    -- entities are sized f64
    local packet = buffer.create(#batch * (8 + ty.size))
    local offset = 0
    for _, entityData in batch do
        offset+=8
        buffer.writef64(packet, offset, entityData.entity)
        if ty.type == "Vector3" then
            local vec3 = entity.data :: Vector3
            offset += 4
            buffer.writei32(packet, offset, vec3.X)
            offset += 4
            buffer.writei32(packet, offset, vec3.Y)
            offset += 4
            buffer.writei32(packet, offset, vec3.Z)
        end
    end

    updatePositions:FireServer(packet)
end
```

```typescript [typescript]
const Networked = world.component();
const Type = world.component();
const Name = world.component();
const Position = world.component<Vector3>();
world.add(Position, Networked);
world.set(Position, Name, "Position");
world.set(Position, Type, { size: 12, type: "Vector3" }); // 12 bytes to represent a Vector3

for (const [id, ty, name] of world.query(Type, Name, Networked)) {
	const batch = new Array<{ entity: Entity; data: unknown }>();

	for (const [entity, data] of world.query(id)) {
		batch.push({ entity, data });
	}
	// entities are sized f64
	const packet = buffer.create(batch.size() * (8 + ty.size));
	const offset = 0;
	for (const [_, entityData] of batch) {
		offset += 8;
		buffer.writef64(packet, offset, entityData.entity);
		if (ty.type == "Vector3") {
			const vec3 = entity.data as Vector3;
			offset += 4;
			buffer.writei32(packet, offsetm, vec3.X);
			offset += 4;
			buffer.writei32(packet, offset, vec3.Y);
			offset += 4;
			buffer.writei32(packet, offset, vec3.Z);
		}
	}

	updatePositions.FireServer(packet);
}
```

:::

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
