local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ct = require(ReplicatedStorage.components)
local types = require(ReplicatedStorage.types)
local jecs = require(ReplicatedStorage.ecs)

return function(world: types.World, dt: number)
	for e, poison_tick in world:query(ct.Poison, jecs.pair(jecs.ChildOf, jecs.w)) do
		local tgt = world:target(e, jecs.ChildOf)
		local health = world:get(tgt, ct.Health)
		if not health then
			continue
		end

		if math.random() < 1 / 60 / 1 and health > 1 then
			world:set(tgt, ct.Health, health - 1)
		end
	end
end
