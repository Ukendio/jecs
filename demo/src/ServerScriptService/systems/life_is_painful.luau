local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ct = require(ReplicatedStorage.components)
local types = require(ReplicatedStorage.types)
local jecs = require(ReplicatedStorage.ecs)

return function(world: types.World, dt: number)
	if math.random() < (1 / 60 / 7) then
		for e in world:each(ct.Health) do
			local poison = world:entity()
			world:add(poison, ct.Debuff)
			world:add(poison, jecs.pair(jecs.ChildOf, e))
			world:set(poison, ct.Poison, 10)
			world:set(poison, ct.Lifetime, {
				duration = 3,
				created = os.clock()
			})
		end
	end
end
