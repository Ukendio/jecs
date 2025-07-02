local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ct = require(ReplicatedStorage.components)
local types = require(ReplicatedStorage.types)

return function(world: types.World, dt: number)
	for e in world:query(ct.Player):without(ct.Health) do
		world:set(e, ct.Health, 100)
	end

	for e, health in world:query(ct.Health) do
		if math.random() < 1 / 60 / 30 then
			world:set(e, ct.Health, 100)
		end
	end
end
