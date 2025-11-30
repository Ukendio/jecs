--[[
	Understanding the basic architecture of queries helps to make the right
	tradeoffs when using queries in games. The biggest impact on query performance
	is whether a query is cached or not. This section goes over what caching is,
	how it can be used and when it makes sense to use it.

	Caching: what is it?

	Jecs is an archetype ECS, which means that entities with exactly the same
	components are grouped together in an "archetype". Archetypes are created
	on the fly whenever a new component combination is created in the ECS.
]]

local jecs = require("@jecs")
local world = jecs.world()

local Position = world:component() :: jecs.Id<vector>
local Velocity = world:component() :: jecs.Id<vector>
local Mass = world:component() :: jecs.Id<number>

local e1 = world:entity()
world:set(e1, Position, vector.create(10, 20, 30)) -- create archetype [Position]
world:set(e1, Velocity, vector.create(1, 2, 3))    -- create archetype [Position, Velocity]

local e2 = world:entity()
world:set(e2, Position, vector.create(10, 20, 30)) -- archetype [Position] already exists
world:set(e2, Velocity, vector.create(1, 2, 3))    -- archetype [Position, Velocity] already exists
world:set(e2, Mass, 100)                           -- create archetype [Position, Velocity, Mass]

-- e1 is now in archetype [Position, Velocity]
-- e2 is now in archetype [Position, Velocity, Mass]

--[[
	Archetypes are important for queries. Since all entities in an archetype have
	the same components, and a query matches entities with specific components,
	a query can often match entire archetypes instead of individual entities.
	This is one of the main reasons why queries in an archetype ECS are fast.

	The second reason that queries in an archetype ECS are fast is that they are
	cheap to cache. While an archetype is created for each unique component
	combination, games typically only use a finite set of component combinations
	which are created quickly after game assets are loaded.

	This means that instead of searching for archetypes each time a query is
	evaluated, a query can instead cache the list of matching archetypes. This
	is a cheap cache to maintain: even though entities can move in and out of
	archetypes, the archetypes themselves are often stable.

	If none of that made sense, the main thing to remember is that a cached query
	does not actually have to search for entities. Iterating a cached query just
	means iterating a list of prematched results, and this is really, really fast.

	Tradeoffs

	Jecs has both cached and uncached queries. If cached queries are so fast,
	why even bother with uncached queries? There are four main reasons:

	- Cached queries are really fast to iterate, but take more time to create
	  because the cache must be initialized first.
	- Cached queries add overhead to archetype creation/deletion, as these changes
	  have to get propagated to caches.
	- While caching archetypes is fast, some query features require matching
	  individual entities, which are not efficient to cache (and aren't cached).

	As a rule of thumb, if you have a query that is evaluated each frame (as is
	typically the case with systems), they will benefit from being cached.
	If you need to create a query ad-hoc, an uncached query makes more sense.

	Ad-hoc queries are often necessary when a game needs to find entities that
	match a condition that is only known at runtime, for example to find all
	child entities for a specific parent.
]]

-- Uncached query (default)
for entity, pos, vel in world:query(Position, Velocity) do
	-- Process entities
end

-- Cached query (faster for repeated use)
local cached_query = world:query(Position, Velocity):cached()
for entity, pos, vel in cached_query do
	-- Process entities - this is faster for repeated iterations
end

