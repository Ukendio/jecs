local jecs = require("@jecs")
local pair = jecs.pair
local world = jecs.world()

local Likes = world:component()

--[[
	Fragmentation is a property of archetype-based ECS implementations where entities
	are spread out over more archetypes as the number of different component combinations
	increases. The overhead of fragmentation is visible in two areas:
	- Archetype creation
	- Queries (queries have to match & iterate more archetypes)

	Games that make extensive use of relationships might observe high levels of
	fragmentation, as relationships can introduce many different combinations of
	components. While the Jecs storage is optimized for supporting large amounts
	(hundreds of thousands) of archetypes, fragmentation is a factor to consider
	when using relationships.

	To improve the speed of evaluating queries, Jecs has indices that store all
	archetypes for a given component ID. Whenever a new archetype is created, it is
	registered with the indices for the IDs the archetype has, including IDs for
	relationship pairs.

	While registering an archetype for a relationship index is not more expensive
	than registering an archetype for a regular index, an archetype with relationships
	has to also register itself with the appropriate wildcard indices for its
	relationships. For example, an archetype with relationship pair(Likes, Apples)
	registers itself with the pair(Likes, Apples), pair(Likes, jecs.Wildcard) and
	pair(jecs.Wildcard, Apples) indices. For this reason, creating new archetypes
	with relationships has a higher overhead than an archetype without relationships.
]]

local alice = world:entity()
local bob = world:entity()
local charlie = world:entity()

local e1 = world:entity()
world:add(e1, pair(Likes, alice))  	-- Creates archetype [pair(Likes, alice)]

local e2 = world:entity()
world:add(e2, pair(Likes, bob))   	-- Creates archetype [pair(Likes, bob)]

local e3 = world:entity()
world:add(e3, pair(Likes, charlie)) -- Creates archetype [pair(Likes, charlie)]

-- Each different target creates a new archetype, leading to fragmentation
-- This is why relationships can increase archetype count significantly
