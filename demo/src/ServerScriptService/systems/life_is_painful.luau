local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ct = require(ReplicatedStorage.components)
local types = require(ReplicatedStorage.types)

return function(world: types.World, dt: number)
	for e in world:query(ct.Player):without(ct.Health) do
		world:set(e, ct.Health, 100)
	end
	for e in world:query(ct.Player, ct.Health):without(ct.Poison) do
		world:set(e, ct.Poison, 10)
	end
end
