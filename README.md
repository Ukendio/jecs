<p align="center">
  <img src="assets/image-5.png" width=35%/>
</p>

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE) [![Wally](https://img.shields.io/github/v/tag/ukendio/jecs?&style=for-the-badge)](https://wally.run/package/ukendio/jecs)

Just a stupidly fast Entity Component System

-   [Entity Relationships](https://ajmmertens.medium.com/building-games-in-ecs-with-entity-relationships-657275ba2c6c) as first class citizens
-   Iterate 800,000 entities at 60 frames per second
-   Type-safe [Luau](https://luau-lang.org/) API
-   Zero-dependency package
-   Optimized for column-major operations
-   Cache friendly [archetype/SoA](https://ajmmertens.medium.com/building-an-ecs-2-archetypes-and-vectorization-fe21690805f9) storage
-   Rigorously [unit tested](https://github.com/Ukendio/jecs/actions/workflows/ci.yaml) for stability

### Example

```lua
local world = jecs.World.new()
local pair = jecs.pair

-- These components and functions are actually already builtin
-- but have been illustrated for demonstration purposes
local ChildOf = world:component()
local Name = world:component()

local function parent(entity)
    return world:target(entity, ChildOf)
end
local function getName(entity)
    return world:get(entity, Name)
end

local alice = world:entity()
world:set(alice, Name, "alice")

local bob = world:entity()
world:add(bob, pair(ChildOf, alice))
world:set(bob, Name, "bob")

local sara = world:entity()
world:add(sara, pair(ChildOf, alice))
world:set(sara, Name, "sara")

print(getName(parent(sara)))

for e in world:query(pair(ChildOf, alice)) do
    print(getName(e), "is the child of alice")
end

-- Output
-- "alice"
-- bob is the child of alice
-- sara is the child of alice
```

21,000 entities 125 archetypes 4 random components queried.
![Queries](assets/image-3.png)
Can be found under /benches/visual/query.luau

Inserting 8 components to an entity and updating them over 50 times.
![Insertions](assets/image-4.png)
Can be found under /benches/visual/insertions.luau
