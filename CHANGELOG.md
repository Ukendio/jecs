# Jecs Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][kac], and this project adheres to
[Semantic Versioning][semver].

[kac]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html

## [Unreleased]

-   `[world]`:
    -   16% faster `world:get`
-   `[typescript]`

    -   Fixed Entity type to default to `undefined | unknown` instead of just `undefined`

-   `[query]`:
    -   Fixed bug where `world:clear` did not invoke `jecs.OnRemove` hooks
    -   Changed `query.__iter` to drain on iteration
        -   It will initialize once wherever you left iteration off at last time
    -   Changed `query:iter` to restart the iterator
    -   Removed `query:drain` and `query:next`
        -   If you want to get individual results outside of a for-loop, you need to call `query:iter` to initialize the iterator and then call the iterator function manually
        ```lua
        local it = world:query(A, B, C):iter()
        local entity, a, b, c = it()
        entity, a, b, c = it() -- get next results
        ```
-   `[world`
    -   Fixed a bug with `world:clear` not invoking `jecs.OnRemove` hooks
-   `[typescript]`:
    -   Changed pair to accept generics
    -   Improved handling of Tags

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

    -   IDs created with `world:component()` will promote array lookups rather than map lookups in the `componentIndex` which is a significant boost

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
