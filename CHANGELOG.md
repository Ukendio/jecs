# Jecs Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][kac], and this project adheres to
[Semantic Versioning][semver].

[kac]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html

## [Unreleased]

## [0.2.2] - 2024-07-07

### Added

- Added `query:replace(function(...T) return ...U end)` for replacing components in place
  - Method is fast pathed to replace the data to the components for each corresponding entity

### Changed

- Iterator now goes backwards instead to prevent common cases of iterator invalidation

## [0.2.1] - 2024-07-06

### Added

- Added `jecs.Component` built-in component which will be added to ids created with `world:component()`.
    - Used to find every component id with `query(jecs.Component)

## [0.2.0] - 2024-07-03

### Added

- Added `world:parent(entity)` and `jecs.ChildOf` respectively as first class citizen for building parent-child relationships.
    - Give a parent to an entity with `world:add($source, pair(ChildOf, $target))`
    - Use `world:parent(entity)` to find the target of the relationship
- Added user-facing Luau types

### Changed
- Improved iteration speeds 20-40% by manually indexing rather than using `next()` :scream:


## [0.1.1] - 2024-05-19

### Added

- Added `world:clear(entity)` for removing the components to the corresponding entity
- Added Typescript Types

## [0.1.0] - 2024-05-13

### Changed
- Optimized iterator

## [0.1.0-rc.6] - 2024-05-13

### Added

- Added a `jecs.Wildcard` term
    - it lets you query any partially matched pairs

## [0.1.0-rc.5] - 2024-05-10

### Added

- Added Entity relationships for creating logical connections between entities
- Added `world:__iter method` which allows for iteration over the whole world to get every entity
    - used for reconciling whole worlds such as via replication, saving/loading, etc
- Added `world:add(entity, component)` which adds a component to the entity
    - it is an idempotent function, so calling it twice and in any order should be fine

### Fixed
- Fixed component overriding when in disorder
    - Previously setting the components in different order results in it overriding component data because it incorrectly mapped the index of the column. So it took the index from the source archetype rather than the destination archetype

## [0.0.0-prototype.rc.3] - 2024-05-01

### Added

- Added observers
- Added an arm to query `query:without()` for chaining invariants.

### Changed
- Separates ranges for components and entity IDs.
    - IDs created with `world:component()` will promote array lookups rather than map lookups in the `componentIndex` which is a significant boost

- No longer caches the column pointers directly and instead the column indices which stay persistent even when data is reallocated during swap-removals
    - This was an issue with the iterator being invalidated when you move an entity to a different archetype.

### Fixedhttps://github.com/Ukendio/jecs/releases/tag/v0.0.0-prototype.rc.3

- Fixed a bug where changing an existing component would be slow because it was always appending changing the row of the entity record
    - The fix dramatically improves times where it is basically down to just the speed of setting a field in a table

## [0.0.0-prototype.rc.2] - 2024-04-26

### Changed
- Optimized the creation of the query
    - It will now finds the smallest archetype map to iterate over
- Optimized the query iterator
    - It will now populates iterator with columns for faster indexing

- Renamed the insertion method from world:add to world:set to better reflect what it does.

## [0.0.0-prototype.rc.2] - 2024-04-23
- Initial release

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
