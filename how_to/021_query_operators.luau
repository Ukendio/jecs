--[[
	Filters are extensions to queries which allow you to select entities from
	a more complex pattern but you don't actually care about the component values.

	The following filters are supported by queries:

	| Identifier | Description                         |
	| ---------- | ----------------------------------- |
	| With       | Must match with all terms.          |
	| Without    | Must not match with provided terms. |
]]

local jecs = require("@jecs")
local world = jecs.world()

local Position = world:component() :: jecs.Id<vector>
local Velocity = world:component() :: jecs.Id<vector>
local Walking = world:component()

-- Query with filter: entities that have Position and Velocity, but we don't
-- need the values, just want to know they exist
world:query(Position, Velocity)
	:with(Walking)  -- Must also have Walking tag
	:without(Velocity)     -- Can specify components to exclude

-- Wildcards
--[[
	Jecs currently only supports the Any type of wildcards which a single result
	for the first component that it matches.

	When using the Any type wildcard it is undefined which component will be
	matched, as this can be influenced by other parts of the query. It is guaranteed
	that iterating the same query twice on the same dataset will produce the same result.

	If you want to iterate multiple targets for the same relation on a pair,
	then use world:target()
]]
