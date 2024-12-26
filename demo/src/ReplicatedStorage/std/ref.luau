local world = require(script.Parent.world)
local jecs = require(game:GetService("ReplicatedStorage").ecs)
local refs: {[any]: jecs.Entity} = {}

local function fini(key): () -> ()
	return function()
		refs[key] = nil
	end
end

local function noop() end

local function ref(key): (jecs.Entity, () -> ())
	if not key then
		return world:entity(), noop
	end
	local e = refs[key]
	if not e then
		e = world:entity()
		refs[key] = e
	end
	-- Cannot cache handles because they will get invalidated
	return e, fini(key)
end

return ref
