--!optimize 2
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Lib:Clone())
local ecs = jecs.world()
local mirror = require(ReplicatedStorage.mirror:Clone())
local mcs = mirror.World.new()


local C1 = ecs:component()
local C2 = ecs:component()
local C3 = ecs:component()
local C4 = ecs:component()
local C5 = ecs:component()
local C6 = ecs:component()
local C7 = ecs:component()
local C8 = ecs:component()
local E1 = mcs:component()
local E2 = mcs:component()
local E3 = mcs:component()
local E4 = mcs:component()
local E5 = mcs:component()
local E6 = mcs:component()
local E7 = mcs:component()
local E8 = mcs:component()

return {
	ParameterGenerator = function()
		return
	end,

	Functions = {
		Mirror = function()
			local e = mcs:entity()
			for i = 1, 5000 do
				mcs:set(e, E1, false)
				mcs:set(e, E2, false)
				mcs:set(e, E3, false)
				mcs:set(e, E4, false)
				mcs:set(e, E5, false)
				mcs:set(e, E6, false)
				mcs:set(e, E7, false)
				mcs:set(e, E8, false)
			end
		end,
		Jecs = function()
			local e = ecs:entity()
			for i = 1, 5000 do
				ecs:set(e, C1, false)
				ecs:set(e, C2, false)
				ecs:set(e, C3, false)
				ecs:set(e, C4, false)
				ecs:set(e, C5, false)
				ecs:set(e, C6, false)
				ecs:set(e, C7, false)
				ecs:set(e, C8, false)
			end
		end,
	},
}
