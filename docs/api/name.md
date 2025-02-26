# Name Component

The `Name` component allows you to associate a string identifier with an entity.

## Overview

```luau
jecs.Name: Entity<string>
```

The `Name` component is a built-in component in jecs that stores a string value. It has no special behavior beyond storing a name.

## Usage

### Setting a Name

```luau
local world = jecs.World.new()

-- Create an entity
local entity = world:entity()

-- Assign a name to the entity
world:set(entity, jecs.Name, "Player")
```

### Getting an Entity's Name

```luau
-- Retrieve an entity's name
local name = world:get(entity, jecs.Name)
print("Entity name:", name) -- Outputs: "Entity name: Player"
```

### Finding Entities by Name

```luau
-- Iterate over all entities with the Name component
for entity, name in world:query(jecs.Name) do
  if name == "Player" then
    -- Found the entity named "Player"
    -- Do something with entity...
  end
end
```

### Using Names with Hierarchies

Names are particularly useful when working with entity hierarchies:

```luau
local world = jecs.World.new()
local pair = jecs.pair

-- Create a parent entity with a name
local parent = world:entity()
world:set(parent, jecs.Name, "Parent")

-- Create child entities with names
local child1 = world:entity()
world:set(child1, jecs.Name, "Child1")
world:add(child1, pair(jecs.ChildOf, parent))

local child2 = world:entity()
world:set(child2, jecs.Name, "Child2")
world:add(child2, pair(jecs.ChildOf, parent))

-- Print the hierarchy
print("Parent:", world:get(parent, jecs.Name))
for child in world:query(pair(jecs.ChildOf, parent)) do
  print("  Child:", world:get(child, jecs.Name))
end

-- Output:
-- Parent: Parent
--   Child: Child1
--   Child: Child2
```

## Helper Function

For convenience, you can create a simple helper function to get an entity's name:

```luau
local function getName(world, entity)
  return world:get(entity, jecs.Name) or tostring(entity)
end

-- Usage
local name = getName(world, entity)
```

This function will return the entity's name if it has one, or fall back to the entity ID as a string.

## Best Practices

1. **Use Consistently**: Apply names to key entities systematically, especially for important game objects.

2. **Be Descriptive**: Use meaningful names that describe the entity's role or purpose.

3. **Handle Missing Names**: Always check if an entity has a name before trying to use it, or use a helper function like the one above.

4. **Namespacing**: Consider using prefixes or namespaces for different systems (e.g., "UI:MainMenu", "Enemy:Boss").

5. **Performance**: Remember that adding a Name component to every entity adds memory overhead. Use judiciously in performance-critical applications.

## Example: Entity Debugging System

Here's a simple debugging system that uses the Name component:

```luau
local function debugEntity(world, entity)
  local name = world:get(entity, jecs.Name) or "Unnamed"
  print("Entity", entity, "(" .. name .. ")")
  
  -- Print all components
  for componentId in world:query(jecs.pair(jecs.Component, jecs.Wildcard)) do
    if world:has(entity, componentId) then
      local componentName = world:get(componentId, jecs.Name) or "Unknown"
      local value = world:get(entity, componentId)
      print("  Component:", componentName, "=", value)
    end
  end
end

-- Usage
debugEntity(world, player)
```

This debugging function prints an entity's name along with all its components, making it easier to inspect entities during development. 