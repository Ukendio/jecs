
<p align="center">
  <img src="shorterbanner.png" />
</p>

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache-blue.svg?style=for-the-badge)](LICENSE-APACHE)
[![Wally](https://img.shields.io/github/v/tag/ukendio/jecs?&style=for-the-badge)](https://wally.run/package/ukendio/jecs)

Just an ECS

jecs is a stupidly fast Entity Component System (ECS).

- Process tens of thousands of entities with ease every frame
- Zero-dependency Luau package
- Optimized for column-major operations
- Cache friendly archetype/SoA storage

### Example

```lua
local world = Jecs.World.new()

local Health = world:component()
local Damage = world:component()
local Position = world:component()

local player = world:entity()
local opponent = world:entity()

world:set(player, Health, 100)
world:set(player, Damage, 8)
world:set(player, Position, Vector3.new(0, 5, 0))

world:set(opponent, Health, 100)
world:set(opponent, Damage, 21)
world:set(opponent, Position, Vector3.new(0, 5, 3))

for playerId, playerPosition, health in world:query(Position, Health) do
    local totalDamage = 0
    for _, opponentPosition, damage in world:query(Position, Damage) do
        if (playerPosition - opponentPosition).Magnitude < 5 then
            totalDamage += damage
        end
    end

    world:set(playerId, Health, health - totalDamage)
end

assert(world:get(playerId, Health) == 79)
assert(world:get(opponentId, Health) == 92)
```

125 archetypes, 4 random components queried.
![Queries](image-3.png)
Can be found under /benches/query.lua

Inserting 8 components to an entity and updating them over 50 times.
![Insertions](image-4.png)
Can be found under /benches/insertions.lua
