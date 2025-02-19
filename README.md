<div align="center">
  <img src="assets/image-5.png" width="240" alt="Jecs Logo"/>
  
  # Jecs
  ### Just a Stupidly Fast Entity Component System
  
  [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE) 
  [![Wally](https://img.shields.io/github/v/tag/ukendio/jecs?&style=for-the-badge)](https://wally.run/package/ukendio/jecs)
</div>

## ✨ Features

- 🚀 **Blazing Fast:** Iterate over 800,000 entities at 60 FPS
- 🔗 **Entity Relationships:** First-class support for [entity relationships](https://ajmmertens.medium.com/building-games-in-ecs-with-entity-relationships-657275ba2c6c)
- 📝 **Type Safety:** Fully typed [Luau](https://luau-lang.org/) API
- 🎯 **Zero Dependencies:** Simple integration with no external dependencies
- ⚡ **Optimized Storage:** Cache-friendly [archetype/SoA](https://ajmmertens.medium.com/building-an-ecs-2-archetypes-and-vectorization-fe21690805f9) storage
- ✅ **Battle-tested:** [Rigorously tested](https://github.com/Ukendio/jecs/actions/workflows/ci.yaml) for stability

## 🚀 Example Usage

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

## ⚡ Performance

### Query Performance
21,000 entities, 125 archetypes, 4 random components queried:
![Queries](assets/image-3.png)
*Benchmark source: /benches/visual/query.luau*

### Insertion Performance
Inserting 8 components to an entity and updating them over 50 times:
![Insertions](assets/image-4.png)
*Benchmark source: /benches/visual/insertions.luau*

## 📖 Documentation

- [Getting Started](docs/learn/overview/get-started.md)
- [API Reference](docs/api/jecs.md)
- [Examples](examples/)
- [Common Issues](docs/learn/faq/common-issues.md)

## 🤝 Contributing

Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting pull requests.

## 💬 Community

- Join our [Discord](https://discord.gg/h2NV8PqhAD)
- Report issues on [GitHub](https://github.com/ukendio/jecs/issues)

## 📄 License

Jecs is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.