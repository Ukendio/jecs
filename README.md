<p align="center">
  <img src="assets/image-5.png" width=35%/>
</p>
<!-- <div align="center">
  <img src="assets/image-5.png" width="240" alt="Jecs Logo"/> -->

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE) [![Wally](https://img.shields.io/github/v/tag/ukendio/jecs?&style=for-the-badge)](https://wally.run/package/ukendio/jecs)
  # Jecs
  ### Just a Stupidly Fast ECS for Roblox

  [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)
  [![Wally](https://img.shields.io/github/v/tag/ukendio/jecs?&style=for-the-badge)](https://wally.run/package/ukendio/jecs)

# Jecs - Just a Stupidly Fast ECS
  A high-performance Entity Component System (ECS) for Roblox games, with first-class support for both Luau and TypeScript.
</div>

A high-performance Entity Component System (ECS) for Roblox games, supporting both Luau and TypeScript.
## ✨ Features

## Features
- 🚀 **Blazing Fast:** Iterate over hundreds of thousands of entities at 60 FPS
- 🔗 **Entity Relationships:** First-class support for entity relationships
- 🏷️ **Component Traits:** Add metadata and behavior to components
- 📝 **Type Safety:** Fully typed API for both Luau and TypeScript
- 🎯 **Zero Dependencies:** Simple integration with no external dependencies
- ⚡ **Optimized Storage:** Cache-friendly archetype/SoA storage
- ✅ **Battle-tested:** Comprehensive test coverage
- 📚 **Well Documented:** Clear, thorough documentation and examples

* **Blazing Fast:**  Iterate over hundreds of thousands of entities at 60 frames per second.  Benchmark results are available in the documentation.
* **Entity Relationships:** First-class support for defining and querying relationships between entities.
* **Type Safety:** Fully typed API for both Luau and TypeScript, enhancing code maintainability and reducing errors.
* **Zero Dependencies:** No external dependencies required, simplifying integration into your project.
* **Optimized Storage:** Cache-friendly archetype/SoA (Structure of Arrays) storage for optimal performance.
* **Battle-tested:** Rigorously unit tested for stability and reliability.
* **Comprehensive Documentation:**  Detailed documentation guides you through installation, usage, and advanced concepts.
## 🚀 Quick Start

### Installation

## Documentation

* [Getting Started](docs/learn/overview/get-started.md)
* [API Reference](docs/api/jecs.md)  (Note:  This link may need updating to reflect the actual location of the API docs if they are generated separately)
* [Concepts](docs/learn/concepts/)
    * Entities and Components
    * Queries
    * Relationships
    * Component Traits
    * Addons
* [Examples](examples/)
* [FAQ](docs/learn/faq/common-issues.md)
* [Contributing](docs/contributing/)


## Quick Example (Luau)

```lua
local world = jecs.World.new()
local Position = world:component() :: jecs.Entity<Vector3>
local Velocity = world:component() :: jecs.Entity<Vector3>

local entity = world:entity()
world:set(entity, Position, Vector3.new(0, 0, 0))
world:set(entity, Velocity, Vector3.new(1, 0, 0))

-- Update system (example)
for id, position, velocity in world:query(Position, Velocity) do
    world:set(id, Position, position + velocity)
end
```

## Quick Example (TypeScript)

```typescript
import { World } from "@rbxts/jecs";

const world = new World();
const Position = world.component<Vector3>();
const Velocity = world.component<Vector3>();

const entity = world.entity();
world.set(entity, Position, new Vector3(0, 0, 0));
world.set(entity, Velocity, new Vector3(1, 0, 0));

// Update system (example)
for (const [id, position, velocity] of world.query(Position, Velocity)) {
    world.set(id, Position, position.add(velocity));
}
```

## Performance

Benchmark results demonstrating Jecs' performance are available in the documentation.  These include query and insertion performance tests.

## Installation

### Using Wally (Luau)

Add Jecs to your `wally.toml`:

Using Wally (recommended):
```toml
[dependencies]
jecs = "ukendio/jecs@0.2.3"
```

Then run:

```bash
wally install
```

### Using npm (Roblox-ts)

```bash
npm install @rbxts/jecs
```

### Standalone Installation

1. Download `jecs.rbxm` from the [releases page](https://github.com/ukendio/jecs/releases).
2. Import it into your Roblox project.


## Contributing

We welcome contributions! Please see our [contribution guidelines](docs/contributing/guidelines.md) for details.

## Community & Support

* [Discord Community](https://discord.gg/h2NV8PqhAD)
* [GitHub Issues](https://github.com/ukendio/jecs/issues)
* [API Documentation](https://ukendio.github.io/jecs/) (Note: This link may need updating)

## License

Jecs is [MIT licensed](LICENSE).

```

Jecs = "ukendio/jecs@VERSION"
```
