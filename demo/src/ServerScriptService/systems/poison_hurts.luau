local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ct = require(ReplicatedStorage.components)
return function(world, dt)
	for e, poison, health in world:query(ct.Poison, ct.Health) do
		local health_after_tick = health - poison * dt * 0.05
		if health_after_tick < 0 then
			world:remove(e, ct.Health)
			continue
		end
		world:set(e, ct.Health, health_after_tick)
	end
end
