--!optimize 2
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.DevPackages.Matter)
local ecr = require(ReplicatedStorage.DevPackages.ecr)
local jecs = require(ReplicatedStorage.Lib)
local newWorld = Matter.World.new()
local ecs = jecs.World.new()
local mirror = require(ReplicatedStorage.mirror)
local mcs = mirror.World.new()

local A1 = Matter.component()
local A2 = Matter.component()
local A3 = Matter.component()
local A4 = Matter.component()
local A5 = Matter.component()
local A6 = Matter.component()
local A7 = Matter.component()
local A8 = Matter.component()

local B1 = ecr.component()
local B2 = ecr.component()
local B3 = ecr.component()
local B4 = ecr.component()
local B5 = ecr.component()
local B6 = ecr.component()
local B7 = ecr.component()
local B8 = ecr.component()

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

local registry2 = ecr.registry()
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
