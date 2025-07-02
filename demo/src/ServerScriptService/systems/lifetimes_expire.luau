
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ct = require(ReplicatedStorage.components)
local types = require(ReplicatedStorage.types)

return function(world: types.World, dt: number)
	for e, lifetime in world:query(ct.Lifetime) do
		if os.clock() > lifetime.created + lifetime.duration then
			world:add(e, ct.Destroy)
		end
	end
end
