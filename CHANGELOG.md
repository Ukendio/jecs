# Jecs Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][kac], and this project adheres to
[Semantic Versioning][semver].

[kac]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html

## [Unreleased]

-   `[world]`:
    -   Added `world:range` to allow for creating
    -   Changed `world:clear` to also look through the component record for the cleared `ID`
        -   Removes the cleared ID from every entity that has it
    -   Changed entity ID layouts by putting the index in the lower bits, which should make every world function 1-5 nanoseconds faster
    -   Fixed `world:delete` not removing every pair with an unalive target
        -   Specifically happened when you had at least two pairs of different relations with multiple targets each
-   `[hooks]`:
    -   Replaced `OnSet` with `OnChange`
        -   The former was used to detect emplace/move actions. Now the behaviour for `OnChange` is that it will run only when the value has changed
    -   Changed `OnAdd` to specifically run after the data has been set for non-zero-sized components. Also returns the value that the component was set to
        -   This should allow a more lenient window for modifying data
    -   Changed `OnRemove` to lazily lookup which archetype the entity will move to
        -   Can now have interior structural changes within `OnRemove` hooks
    -   Optimized `world:has` for both single component and multiple component presence.
        -   This comes at the cost that it cannot check the component presence for more than 4 components at a time. If this is important, consider calling to this function multiple times.

## [0.5.0] - 2024-12-26

-   `[world]`:
    -   Fixed `world:target` not giving adjacent pairs
    -   Added `world:each` to find entities with a specific Tag
    -   Added `world:children` to find children of entity
-   `[query]`:
    -   Added `query:cached`
        -   Adds query cache that updates itself when an archetype matching the query gets created or deleted.
-   `[luau]`:
    -   Changed how entities' types are inferred with user-defined type functions
    -   Changed `Pair<First, Second>` to return `Second` if `First` is a `Tag`; otherwise, returns `First`.

## [0.4.0] - 2024-11-17

-   `[world]`:
    -   Added recycling to `world:entity`
        -   If you see much larger entity ids, that is because its generation has been incremented
-   `[query]`:
    -   Removed `query:drain`
        -   The default behaviour is simply to drain the iterator
    -   Removed `query:next`
        -   Just call the iterator function returned by `query:iter` directly if you want to get the next results
    -   Removed `query:replace`
-   `[luau]`:
    -   Fixed `query:archetypes` not taking `self`
    -   Changed so that the `jecs.Pair` type now returns the first element's type so you won't need to typecast anymore.

## [0.3.2] - 2024-10-01

-   `[world]`:
    -   Changed `world:cleanup` to traverse a header type for graph edges. (Edit)
    -   Fixed a regression that occurred when you call `world:set` following a `world:remove` using the same component
    -   Remove explicit error in JECS_DEBUG for `world:target` when not applying an index parameter
-   `[typescript]` :
    -   Fixed `world.set` with NoInfer<T>

## [0.3.1] - 2024-10-01

-   `[world]`:
    -   Added an index parameter to `world:target`
    -   Added a way to change the components limit via `_G.JECS_HI_COMPONENT_ID`
        -   Set it to whatever number you want but try to make it as close to the number of components you will use as possible
        -   Make sure to set this before importing jecs or else it will not work
    -   Added debug mode, enable via setting `_G.JECS_DEBUG` to true
        -   Make sure to set this before importing jecs or else it will not work
    -   Added `world:cleanup` which is called to cleanup empty archetypes manually
    -   Changed `world:delete` to delete archetypes that are dependent on the passed entity
    -   Changed `world:delete` to delete entity's children before the entity to prevent cycles
-   `[query]`:
    -   Fixed the iterator to not drain by default
-   `[typescript]`
    -   Fixed entry point of the package.json file to be `src` rather than `src/init`
    -   Fixed `query.next` returning a query object whereas it would be expected to return a tuple containing the entity and the corresponding component values
    -   Exported `query.archetypes`
    -   Changed `pair` to return a number instead of an entity
        -   Preventing direct usage of a pair as an entity while still allowing it to be used as a component
    -   Exported built-in components `ChildOf` and `Name`
    -   Exported `world.parent`

## [0.2.10] - 2024-09-07

-   `[world]`:
    -   Improved performance for hooks
    -   Changed `world:set` to be idempotent when setting tags
-   `[traits]`:
    -   Added cleanup condition `jecs.OnDelete` for when the entity or component is deleted
    -   Added cleanup action `jecs.Remove` which removes instances of the specified (component) id from all entities
        -   This is the default cleanup action
    -   Added component trait `jecs.Tag` which allows for zero-cost components used as tags
        -   Setting data to a component with this trait will do nothing
-   `[luau]`:
    -   Exported `world:contains()`
    -   Exported `query:drain()`
    -   Exported `Query`
    -   Improved types for the hook `OnAdd`, `OnSet`, `OnRemove`
    -   Changed functions to accept any ID including pairs in type parameters
        -   Applies to `world:add()`, `world:set()`, `world:remove()`, `world:get()`, `world:has()` and `world:query()`
        -   New exported type `Id<T = nil> = Entity<T> | Pair`
    -   Changed `world:contains()` to return a `boolean` instead of an entity which may or may not exist
    -   Fixed `world:has()` to take the correct parameters

## [0.2.2] - 2024-07-07

### Added

-   Added `query:replace(function(...T) return ...U end)` for replacing components in place
    -   Method is fast pathed to replace the data to the components for each corresponding entity

### Changed

-   Iterator now goes backwards instead to prevent common cases of iterator invalidation

## [0.2.1] - 2024-07-06

### Added

-   Added `jecs.Component` built-in component which will be added to ids created with `world:component()`.
    -   Used to find every component id with `query(jecs.Component)

## [0.2.0] - 2024-07-03

### Added

-   Added `world:parent(entity)` and `jecs.ChildOf` respectively as first class citizen for building parent-child relationships.
    -   Give a parent to an entity with `world:add($source, pair(ChildOf, $target))`
    -   Use `world:parent(entity)` to find the target of the relationship
-   Added user-facing Luau types

### Changed

-   Improved iteration speeds 20-40% by manually indexing rather than using `next()` :scream:

## [0.1.1] - 2024-05-19

### Added

-   Added `world:clear(entity)` for removing the components to the corresponding entity
-   Added Typescript Types

## [0.1.0] - 2024-05-13

### Changed

-   Optimized iterator

## [0.1.0-rc.6] - 2024-05-13

### Added

-   Added a `jecs.Wildcard` term
    -   it lets you query any partially matched pairs

## [0.1.0-rc.5] - 2024-05-10

### Added

-   Added Entity relationships for creating logical connections between entities
-   Added `world:__iter method` which allows for iteration over the whole world to get every entity
    -   used for reconciling whole worlds such as via replication, saving/loading, etc
-   Added `world:add(entity, component)` which adds a component to the entity
    -   it is an idempotent function, so calling it twice and in any order should be fine

### Fixed

-   Fixed component overriding when in disorder
    -   Previously setting the components in different order results in it overriding component data because it incorrectly mapped the index of the column. So it took the index from the source archetype rather than the destination archetype

## [0.0.0-prototype.rc.3] - 2024-05-01

### Added

-   Added observers
-   Added an arm to query `query:without()` for chaining invariants.

### Changed

-   Separates ranges for components and entity IDs.

    -   IDs created with `world:component()` will promote array lookups rather than map lookups in the `component_index` which is a significant boost

-   No longer caches the column pointers directly and instead the column indices which stay persistent even when data is reallocated during swap-removals
    -   This was an issue with the iterator being invalidated when you move an entity to a different archetype.

### Fixedhttps://github.com/Ukendio/jecs/releases/tag/v0.0.0-prototype.rc.3

-   Fixed a bug where changing an existing component would be slow because it was always appending changing the row of the entity record
    -   The fix dramatically improves times where it is basically down to just the speed of setting a field in a table

## [0.0.0-prototype.rc.2] - 2024-04-26

### Changed

-   Optimized the creation of the query
    -   It will now finds the smallest archetype map to iterate over
-   Optimized the query iterator

    -   It will now populates iterator with columns for faster indexing

-   Renamed the insertion method from world:add to world:set to better reflect what it does.

## [0.0.0-prototype.rc.2] - 2024-04-23

-   Initial release

[unreleased]: https://github.com/ukendio/jecs/compare/v0.0.0.0-prototype.rc.2...HEAD
[0.2.2]: https://github.com/ukendio/jecs/releases/tag/v0.2.2
[0.2.1]: https://github.com/ukendio/jecs/releases/tag/v0.2.1
[0.2.0]: https://github.com/ukendio/jecs/releases/tag/v0.2.0
[0.1.1]: https://github.com/ukendio/jecs/releases/tag/v0.1.1
[0.1.0]: https://github.com/ukendio/jecs/releases/tag/v0.1.0
[0.1.0-rc.6]: https://github.com/ukendio/jecs/releases/tag/v0.1.0-rc.6
[0.1.0-rc.5]: https://github.com/ukendio/jecs/releases/tag/v0.1.0-rc.5
[0.0.0-prototype-rc.3]: https://github.com/ukendio/jecs/releases/tag/v0.0.0-prototype.rc.3
[0.0.0-prototype.rc.2]: https://github.com/ukendio/jecs/releases/tag/v0.0.0-prototype.rc.2
[0.0.0-prototype-rc.1]: https://github.com/ukendio/jecs/releases/tag/v0.0.0-prototype.rc.1
