--!optimize 2
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Lib:Clone())
local mirror = require(ReplicatedStorage.mirror:Clone())



return {
	ParameterGenerator = function()
		local ecs = jecs.world()
		ecs:range(1000, 20000)
		local mcs = mirror.World.new()
		return ecs, mcs
	end,

	Functions = {
		Mirror = function(_, ecs, mcs)
			for i = 1, 100 do

				mcs:entity()
			end
		end,

		Jecs = function(_, ecs, mcs)
			for i = 1, 100 do

				ecs:entity()
			end
		end,
},
}
