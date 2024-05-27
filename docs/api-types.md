# World

A World contains all ECS data
Games can have multiple worlds, although typically only one is necessary. These worlds are isolated from each other, meaning they donot share the same entities nor component IDs.

---

# Entity

An unique id.

Entities consist out of a number unique to the entity in the lower 32 bits, and a counter used to track entity liveliness in the upper 32 bits. When an id is recycled, its generation count is increased. This causes recycled ids to be very large (>4 billion), which is normal.

---

# QueryIter

A result from the `World:query` function.

Queries are used to iterate over entities that match against the set collection of components.

Calling it in a loop will allow iteration over the results.

```lua
for id, enemy, charge, model in world:query(Enemy, Charge, Model) do
	-- Do something
end
```

### QueryIter.without

QueryIter.without(iter: QueryIter
                  ...: [Entity](../api-types/Entity)): QueryIter


Create a new Query Iterator from the filter

#### Parameters
    world   The world.
    ...     The collection of components to filter archetypes against.

#### Returns

The new query iterator.

