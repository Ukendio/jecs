# Frequently Asked Questions

This section addresses common questions about jecs.

## General Questions

### What is jecs?

jecs is a high-performance Entity Component System (ECS) library for Luau/Roblox.

### How does jecs compare to other ECS libraries?

jecs uses an archetype-based storage system (SoA) which is more cache-friendly than traditional approaches. For a detailed comparison with Matter, see the [Migration from Matter](../migration-from-matter.md) guide.

### Can I use jecs outside of Roblox?

Yes, jecs can be used in any Lua/Luau environment as it has zero dependencies.

## Technical Questions

### How many entities can jecs handle?

jecs can handle up to 800,000 entities at 60 frames per second.

### What are archetypes?

Archetypes are groups of entities that have the exact same set of components. When you add or remove components from an entity, it moves to a different archetype.

### How do I optimize performance with jecs?

- Group entity operations to minimize archetype transitions
- Use cached queries for frequently accessed data
- Define components that are frequently queried together
- Use tags instead of empty tables
- Be mindful of archetype transitions

### What are relationship pairs?

Relationship pairs allow you to create connections between entities using the `pair()` function.

## Common Issues

### My entity disappeared after adding a component

Check if you have cleanup policies set up with `OnDelete` or `OnDeleteTarget`.

### Queries are returning unexpected results

Make sure you're querying for the exact components you need. Use modifiers like `.with()` or `.without()` to refine queries.

### Performance degrades over time

This could be due to:
- Memory leaks from not properly deleting entities
- Excessive archetype transitions
- Too many entities or components
- Inefficient queries

### How do I debug entity relationships?

Use the `Name` component to give entities meaningful names:

```lua
-- Print all parent-child relationships
for entity, target in world:query(jecs.pair(jecs.ChildOf, jecs.Wildcard)) do
  print(world:get(entity, jecs.Name), "is a child of", world:get(target, jecs.Name))
end
```

## Best Practices

### When should I use component lifecycle hooks?

Use lifecycle hooks (`OnAdd`, `OnRemove`, `OnSet`) for:
- Initializing resources
- Cleaning up resources
- Reacting to data changes

### How should I structure my ECS code?

- Separate data (components) from behavior (systems)
- Keep components small and focused
- Design systems for specific component combinations
- Use relationships to model connections
- Document cleanup policies

### Should I use multiple worlds?

Multiple worlds are useful for:
- Separating client and server logic
- Creating isolated test environments
- Managing different game states

Component IDs may conflict between worlds if not registered in the same order. 