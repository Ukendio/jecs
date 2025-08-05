# Changelog

## Unreleased

### Added
- Added signals that allow listening to relation part of pairs in signals.

### Changed
- `OnRemove` hooks so that they are allowed to move entity's archetype even during deletion.

## 0.8.0

### Added
- `jecs.Exclusive` trait for making exclusive relationships.

### Changed
- `jecs.ChildOf` to be an exclusive relationship, which means you can only have one `ChildOf` pair on an entity.

## 0.7.2
### Added
- `jecs.entity_index_try_get_fast` back as to not break the observer addon.

### Fixed
- A linting problem with the types for `quer:with` and `query:without`.


## 0.7.0

### Added
- `jecs.component_record` for retrieving the component_record of a component.
- `Column<T>` and `ColumnsMap<T>` types for typescript.
- `bulk_insert` and `bulk_remove` respectively for moving an entity to an archetype without intermediate steps.

### Changed
- The fields `archetype.records[id]` and `archetype.counts[id]` have been removed from the archetype struct and been moved to the component record `component_index[id].records[archetype.id]` and `component_index[id].counts[archetype.id]` respectively.
- Removed the metatable `jecs.World`. Use `jecs.world()` to create your World.
- Archetypes will no longer be garbage collected when invalidated, allowing them to be recycled to save a lot of performance during frequent deletion.
- Removed `jecs.entity_index_try_get_fast`. Use `jecs.entity_index_try_get` instead.

## 0.6.1

### Changed
- Entity types now unions with numbers should allow for easier time casting while not causing regressing previous behaviours

### Fixed
- Fixed a critical bug with `(*, R)` pairs not being removed when `R` is deleted

## 0.6.0

### Added
- `World:range` to restrict entity range to allow for e.g. reserving ids `1000..5000` for clients and everything above that (5000+) for entities from the server. This makes it possible to receive ids from a server that don't have to be mapped to local ids.
- `jecs.component`, `jecs.tag` and `jecs.meta` for preregistering ids and their metadata before a world
- Overload to `World:entity` to create an entity at the desired id.

### Changed
- `World:clear` to remove the `ID` from every entity instead of the previous behaviour of removing all of the components on the entity. You should prefer deleting the entity instead for the previous behaviour.
- Entity ID layouts by putting the index in the lower bits, which should make every world function 1–5 nanoseconds faster.
- Hooks now pass the full component ID which is useful for pairs when you need both the relation and the target.
- Replaced `OnSet` with `OnChange`, which now only runs when the component ID was previously present on the entity.
- `OnAdd` now runs after the value has been set and also passes the component ID and the value.
- `OnRemove` now lazily looks up which archetype the entity will move to. This is meant to support interior structural changes within every hook.
- Optimized `world:has` for both single and multiple component presence. This comes at the cost that it cannot check the component presence for more than 4 components at a time. If this is important, consider calling this function multiple times.

### Fixed
- `World:delete` not removing every pair with an unalive target. Specifically happened when you had at least two pairs of different relations with multiple targets each.

## 0.5.0

### Added
- `World:each` to find entities with a specific Tag.
- `World:children` to find children of an entity.
- `Query:cached` to add a query cache that updates itself when an archetype matching the query gets created or deleted.

### Changed
- Inference of entities' types using user-defined type functions.
- `Pair<First, Second>` to return `Second` if `First` is a `Tag`; otherwise, returns `First`.

### Fixed
- `World:target` not giving adjacent pairs.

## 0.4.0

### Added
- Recycling support to `world:entity` so reused entity IDs now increment generation.

### Removed
- `Query:drain`
- `Query:next`
- `Query:replace`

### Changed
- `jecs.Pair` type in Luau now returns the first element's type to avoid manual typecasting.

### Fixed
- `Query:archetypes` now correctly takes `self`.

## 0.3.2 - 2024-10-01

### Changed
- `World:cleanup` to traverse a header type for graph edges.

### Fixed
- Regression when calling `World:set` after `World:remove` on the same component.
- Removed explicit error in `JECS_DEBUG` for `World:target` missing index.
- `World.set` type inference with `NoInfer<T>` in TypeScript.

## 0.3.1 - 2024-10-01

### Added
- Index parameter to `World:target`.
- Global config `_G.JECS_HI_COMPONENT_ID` to change component ID limit (must be set before importing JECS).
- Debug mode via `_G.JECS_DEBUG` (must be set before importing JECS).
- `world:cleanup` to manually clean up empty archetypes.

### Changed
- `world:delete` now also deletes dependent archetypes and child entities.

### Fixed
- `Query` iterator to not drain by default.
- TypeScript package entry to `src` instead of `src/init`.
- `Query.next` now returns expected result tuple in typescript.
- `pair` returns a number instead of entity to prevent misuse.
- Exported built-in components `ChildOf`, `Name`, and `world.parent`.

## 0.2.10

### Added
- Trait `jecs.Tag` for zero-cost tag components.
- Cleanup conditions: `jecs.OnDelete`, `jecs.Remove`.

### Changed
- `world:set` is now idempotent when setting tags.

### Fixed
- Improved performance for hooks.
- Exported types and functions: `world:contains()`, `query:drain()`, `Query`.
- Hook types: `OnAdd`, `OnSet`, `OnRemove`.
- ID flexibility for `add`, `set`, `remove`, `get`, `has`, `query`.
- `world:contains()` now returns `boolean`.
- `world:has()` parameters now correct.

## 0.2.2

### Added
- `query:replace(fn)` for in-place replacement of component values.

### Changed
- Iterator now goes backwards to avoid invalidation during iteration.

## 0.2.1

### Added
- Built-in `jecs.Component` used to find all component IDs.

## 0.2.0

### Added
- `world:parent(entity)` and `jecs.ChildOf` for parent-child relationships.

### Changed
- Iteration performance improved by 20–40% through manual indexing.

## 0.1.1

### Added
- `world:clear(entity)` for removing all components from an entity.
- TypeScript types.

## 0.1.0

### Changed
- Optimized iterator.

## 0.1.0-rc.6

### Added
- `jecs.Wildcard` term to query partially matched pairs.

## 0.1.0-rc.5

### Added
- Entity relationships.
- `world:__iter()` for full world iteration.
- `world:add(entity, component)` (idempotent).

### Fixed
- Component overriding when set out of order.

## 0.0.0-prototype.rc.3

### Added
- Observers.
- `query:without()` for invariant queries.

### Changed
- Separate ID ranges for entities and components.
- Avoid caching pointers; cache stable column indices instead.

### Fixed
- Slow component updates due to unnecessary row changes.

## 0.0.0-prototype.rc.2 - 2024-04-26

### Changed
- Query now uses smallest archetype map.
- Optimized query iterator.
- Renamed `world:add` to `world:set`.

## 0.0.0-prototype.rc.1

### Added
- Initial release.
