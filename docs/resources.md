## Learning

- [Jecs Demo](https://github.com/Ukendio/jecs/tree/main/demo)
- [Jecs Examples](https://github.com/Ukendio/jecs/tree/main/examples)
- [An Introduction to ECS for Robloxians - @Ukendio](https://devforum.roblox.com/t/all-about-entity-component-system/1664447)
- [Entities, Components and Systems - Mark Jordan](https://medium.com/ingeniouslysimple/entities-components-and-systems-89c31464240d)
- [Why Vanilla ECS is not enough - Sander Mertens](https://ajmmertens.medium.com/why-vanilla-ecs-is-not-enough-d7ed4e3bebe5)
- [Formalisation of Concepts behind ECS and Entitas - Maxim Zaks](https://medium.com/@icex33/formalisation-of-concepts-behind-ecs-and-entitas-8efe535d9516)
- [Entity Component System and Rendering - Our Machinery](https://ourmachinery.com/post/ecs-and-rendering/)
- [Specs and Legion, two very different approaches to ECS - Cora Sherrat](https://csherratt.github.io/blog/posts/specs-and-legion/)
- [Where are my Entities and Components - Sander Mertens](https://ajmmertens.medium.com/building-an-ecs-1-where-are-my-entities-and-components-63d07c7da742)
- [Archetypes and Vectorization - Sander Mertens](https://medium.com/@ajmmertens/building-an-ecs-2-archetypes-and-vectorization-fe21690805f9)
- [Building Games with Entity Relationships - Sander Mertens](https://ajmmertens.medium.com/building-games-in-ecs-with-entity-relationships-657275ba2c6c)
- [Why it is time to start thinking of games as databases - Sander Mertens](https://ajmmertens.medium.com/why-it-is-time-to-start-thinking-of-games-as-databases-e7971da33ac3)
- [A Roadmap to Entity Relationships - Sander Mertens](https://ajmmertens.medium.com/a-roadmap-to-entity-relationships-5b1d11ebb4eb)
- [Making the most of Entity Identifiers - Sander Mertens](https://ajmmertens.medium.com/doing-a-lot-with-a-little-ecs-identifiers-25a72bd2647)
- [Why Storing State Machines in ECS is a Bad Idea - Sander Mertens](https://ajmmertens.medium.com/why-storing-state-machines-in-ecs-is-a-bad-idea-742de7a18e59)
- [ECS back & forth - Michele Caini](https://skypjack.github.io/2019-02-14-ecs-baf-part-1/)
- [Sparse Set - Geeks for Geeks](https://www.geeksforgeeks.org/sparse-set/)
- [Taking the Entity-Component-System Architecture Seriously - @alice-i-cecile](https://www.youtube.com/watch?v=VpiprNBEZsk)
- [Overwatch Gameplay Architecture and Netcode - Blizzard, GDC](https://www.youtube.com/watch?v=W3aieHjyNvw)
- [Data-Oriented Design and C++ - Mike Acton, CppCon](https://www.youtube.com/watch?v=rX0ItVEVjHc)
- [Using Rust for Game Development - Catherine West, RustConf](https://www.youtube.com/watch?v=aKLntZcp27M)
- [CPU caches and why you should care - Scott Meyers, NDC](https://vimeo.com/97337258)
- [Building a fast ECS on top of a slow ECS - @UnitOfTime](https://youtu.be/71RSWVyOMEY)
- [Culling the Battlefield: Data Oriented Design in Practice - DICE, GDC](https://www.gdcvault.com/play/1014491/Culling-the-Battlefield-Data-Oriented)
- [Game Engine Entity/Object Systems - Bobby Anguelov](https://www.youtube.com/watch?v=jjEsB611kxs)
- [Understanding Data Oriented Design for Entity Component Systems - Unity GDC](https://www.youtube.com/watch?v=0_Byw9UMn9g)
- [Understanding Data Oriented Design - Unity](https://learn.unity.com/tutorial/part-1-understand-data-oriented-design?courseId=60132919edbc2a56f9d439c3&signup=true&uv=2020.1)
- [Data Oriented Design - Richard Fabian](https://www.dataorienteddesign.com/dodbook/dodmain.html)
- [Interactive app for browsing systems of City Skylines 2 - @Captain-Of-Coit](https://captain-of-coit.github.io/cs2-ecs-explorer/)
- [Awesome Entity Component System (link collection related to ECS) - Jeongseok Lee](https://github.com/jslee02/awesome-entity-component-system)
- [Hibitset - DOCS.RS](https://docs.rs/hibitset/0.6.3/hibitset/)

## Addons

A collection of third-party jecs addons made by the community. If you would like to share what you're working on, [submit a pull request](/learn/contributing/pull-requests#addons)!

### Development tools

#### [jabby](https://github.com/alicesaidhi/jabby)
A jecs debugger with a string-based query language and entity editing capabilities.

#### [jecs_entity_visualiser](https://github.com/Ukendio/jecs/blob/main/tools/entity_visualiser.luau)
A simple entity and component visualiser in the output

#### [jecs_lifetime_tracker](https://github.com/Ukendio/jecs/blob/main/tools/lifetime_tracker.luau)
A tool for inspecting entity lifetimes

### Helpers

#### [jecs_observers](https://github.com/Ukendio/jecs/blob/main/addons/observers.luau)
Observers for queries and signals for components

### [hammer](https://github.com/Mark-Marks/hammer)
A set of utilities for Jecs

### Schedulers

#### [lockstep scheduler](https://gist.github.com/1Axen/6d4f78b3454cf455e93794505588354b)
A simple fixed step system scheduler.

#### [rubine](https://github.com/Mark-Marks/rubine)
An ergonomic, runtime agnostic scheduler for Jecs

#### [jam](https://github.com/revvy02/Jam)
Provides hooks and a scheduler that implements jabby and a topographical runtime

#### [planck](https://github.com/YetAnotherClown/planck)
An agnostic scheduler inspired by Bevy and Flecs, with core features including phases, pipelines, run conditions, and startup systems.
Planck also provides plugins for Jabby, Matter Hooks, and more.

### Networking

#### [feces](https://github.com/NeonD00m/feces)
A generalized replication system for jecs

### Input

#### [Axis](https://github.com/NeonD00m/axis)
An agnostic, simple and versatile input library for ECS
