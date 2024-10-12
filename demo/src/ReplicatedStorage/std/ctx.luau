local handle = require(script.Parent.handle)
local world = require(script.Parent.world)

local singleton = world:entity()

local function ctx()
	-- Cannot cache handles because they will get invalidated
	return handle(singleton)
end

return ctx
