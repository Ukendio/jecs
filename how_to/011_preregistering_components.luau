--[[
	By default, components being registered on runtime is useful for how dynamic
	it can be. But, sometimes being able to register components without having
	the world instance is useful.
]]

local jecs = require("@jecs")

local Position = jecs.component() :: jecs.Id<vector>

jecs.world() -- Position gets registered here

--[[
	However, if you try to set metadata, you will find that this doesn't work
	without the world instance. Instead, jecs offers a meta member function
	that can forward declare its metadata.
]]

jecs.meta(Position, jecs.Name, "Position")

jecs.world() -- Position gets registered here with its name "Position"
