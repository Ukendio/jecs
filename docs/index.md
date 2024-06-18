---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: "JECS"
  text: "Just an ECS"
  tagline: JECS is a stupidly fast Entity Component System (ECS)
  image: "github"
  actions:
    - theme: brand
      text: Learn JECS
      link: /learn
    - theme: alt
      text: API Usage
      link: /reference
      
features:
  - title: Relational
    icon: "🧑‍🤝‍🧑"
    details: Entity Relationships as first class citizens
  - title: Powerful
    icon: "🔨"
    details: Iterate 350,000 entities at 60 frames per second
  - title: Type Safe
    icon: "👷"
    details: Type-safe Luau API (and soon Typescript 😊)
  - title: Independent
    icon: "⛔"
    details: Zero-dependency package
  - title: Fast
    icon: "⚡"
    details: Optimized for column-major operations
  - title: Memory Safe
    icon: "💾"
    details: Cache friendly archetype/SoA storage
  - title: Stable
    icon: "🛡️"
    details: Unit tested for stability
---
---

# Code Example
```lua
local world = jecs.World.new()
local pair = jecs.pair

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

---
