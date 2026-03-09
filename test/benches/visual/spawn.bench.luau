--!optimize 2
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Lib:Clone())
local mirror = require(ReplicatedStorage.mirror:Clone())



return {
	ParameterGenerator = function()
		local ecs = jecs.world()
		local mcs = mirror.World.new()
		return ecs, mcs
	end,

	Functions = {
		Mirror = function(_, ecs, mcs)
			for i = 1, 100 do

				local _e = mcs:entity()
			end
		end,

		Jecs = function(_, ecs, mcs)
			for i = 1, 100 do

				local _e = ecs:entity()
			end
		end,
},
}
