--!optimize 2
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Lib:Clone())
local mirror = require(ReplicatedStorage.mirror:Clone())

local ecs = jecs.World.new()
local mcs = mirror.world()

return {
	ParameterGenerator = function()
	end,

	Functions = {
		Mirror = function() 
			for i = 1000, 1100 do 
				mcs:entity(i)
			end
		end,
		Jecs = function()
			for i = 1, 1000 do
				ecs:entity(i)
			end
		end,
	},
}
