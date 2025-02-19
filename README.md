<p align="center">
  <img src="assets/image-5.png" width=35%/>
</p>

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE) [![Wally](https://img.shields.io/github/v/tag/ukendio/jecs?&style=for-the-badge)](https://wally.run/package/ukendio/jecs)

# Jecs - Just a Stupidly Fast ECS

A high-performance Entity Component System (ECS) for Roblox games.

## Features

- 🚀 **Blazing Fast**: Iterate over 800,000 entities at 60 frames per second
- 🔗 **Entity Relationships**: First-class support for [entity relationships](docs/learn/concepts/relationships.md)
- 🔒 **Type Safety**: Fully typed API for both [Luau](https://luau-lang.org/) and TypeScript
- 📦 **Zero Dependencies**: No external dependencies required
- ⚡ **Optimized Storage**: Cache-friendly [archetype/SoA](https://ajmmertens.medium.com/building-an-ecs-2-archetypes-and-vectorization-fe21690805f9) storage
- ✅ **Battle-tested**: Rigorously [unit tested](https://github.com/Ukendio/jecs/actions/workflows/ci.yaml) for stability

## Documentation

- [Getting Started](docs/learn/overview/get-started.md)
- [API Reference](docs/api/jecs.md)
- [Concepts](docs/learn/concepts/)
- [Examples](examples/)
- [FAQ](docs/learn/faq/common-issues.md)

## Quick Example

```lua
local world = jecs.World.new()
local pair = jecs.pair

-- Define components
local Position = world:component() :: jecs.Entity<Vector3>
local Velocity = world:component() :: jecs.Entity<Vector3>

-- Create an entity
local entity = world:entity()
world:set(entity, Position, Vector3.new(0, 0, 0))
world:set(entity, Velocity, Vector3.new(1, 0, 0))

-- Update system
for id, position, velocity in world:query(Position, Velocity) do
    world:set(id, Position, position + velocity)
end
```

## Performance

### Query Performance
21,000 entities, 125 archetypes, 4 random components queried:
![Queries](assets/image-3.png)

### Insertion Performance
Inserting 8 components to an entity and updating them over 50 times:
![Insertions](assets/image-4.png)

## Installation

### Using Wally
```toml
[dependencies]
jecs = "ukendio/jecs@0.2.3"
```

### Using npm (roblox-ts)
```bash
npm i @rbxts/jecs
```

### Standalone
Download `jecs.rbxm` from our [releases page](https://github.com/Ukendio/jecs/releases).

## Contributing

We welcome contributions! Please see our [contribution guidelines](docs/contributing/guidelines.md) for details.

## Community & Support

- [Discord Community](https://discord.gg/h2NV8PqhAD)
- [GitHub Issues](https://github.com/ukendio/jecs/issues)
- [API Documentation](https://ukendio.github.io/jecs/)

## License

Jecs is [MIT licensed](LICENSE).
