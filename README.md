Just a stupidly fast Entity Component System

-   [Entity Relationships](https://ajmmertens.medium.com/building-games-in-ecs-with-entity-relationships-657275ba2c6c) as first class citizens
-   Iterate 800,000 entities at 60 frames per second
-   Type-safe [Luau](https://luau-lang.org/) API
-   Zero-dependency package
-   Optimized for column-major operations
-   Cache friendly [archetype/SoA](https://ajmmertens.medium.com/building-an-ecs-2-archetypes-and-vectorization-fe21690805f9) storage
-   Rigorously [unit tested](https://github.com/Ukendio/jecs/actions/workflows/unit-testing.yaml) for stability

### Get Started
This repository includes a few subfolders that can help you get started with jecs:

 how_to:
 	This is a step-by-step introduction to how this ECS works and the reasoning behind its design.

 modules:
 	These are regularly used modules and should be mostly working, but some might not be. You can look in this folder to see some code that you might use to help you hit the ground running quickly.

 examples:
  	These are larger programs that showcase real use cases and can help you understand how everything fits together.


### Benchmarks

21,000 entities 125 archetypes 4 random components queried.
![Queries](assets/image-3.png)
Can be found under /benches/visual/query.luau

Inserting 8 components to an entity and updating them over 50 times.
![Insertions](assets/image-4.png)
Can be found under /benches/visual/insertions.luau
