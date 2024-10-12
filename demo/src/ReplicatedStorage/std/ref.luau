local handle = require(script.Parent.handle)
local world = require(script.Parent.world)
local refs = {}

local function fini(key)
	return function()
		refs[key] = nil
	end
end

local function ref(key): (handle.Handle, (() -> ())?)
	if not key then
		return handle(world:entity())
	end
	local e = refs[key]
	if not e then
		e = world:entity()
		refs[key] = e
	end
	-- Cannot cache handles because they will get invalidated
	return handle(e), fini(key)
end

return ref
