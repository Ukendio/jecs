jecs jit
----------------------------------------------

Standalone ecs module in luajit that can iterate 800,000 entities at 60 frames per second with pure lua. Comes with support for entity relationships, zero-sized-tags, query caching and more.

### Installation

If you are on the luajit branch, the recommended approach to install the library is just copy-pasting the source at jecs.lua

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
