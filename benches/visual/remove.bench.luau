--!optimize 2
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.DevPackages.Matter)
local ecr = require(ReplicatedStorage.DevPackages.ecr)
local jecs = require(ReplicatedStorage.Lib:Clone())
local pair = jecs.pair
local ecs = jecs.world()
local mirror = require(ReplicatedStorage.mirror:Clone())
local mcs = mirror.world()

local C1 = ecs:component()
local C2 = ecs:entity()
ecs:add(C2, pair(jecs.OnDeleteTarget, jecs.Delete))
ecs:add(C2, jecs.Exclusive)

local C3 = ecs:entity()
ecs:add(C3, pair(jecs.OnDeleteTarget, jecs.Delete))
local C4 = ecs:entity()
ecs:add(C4, pair(jecs.OnDeleteTarget, jecs.Delete))
local E1 = mcs:component()
local E2 = mcs:entity()
mcs:add(E2, pair(jecs.OnDeleteTarget, jecs.Delete))
local E3 = mcs:entity()
mcs:add(E3, pair(jecs.OnDeleteTarget, jecs.Delete))
local E4 = mcs:entity()
mcs:add(E4, pair(jecs.OnDeleteTarget, jecs.Delete))

return {
	ParameterGenerator = function()
	end,

	Functions = {
		Mirror = function()
			local m = mcs:entity()
			for i = 1, 100 do
				mcs:add(m, pair(E4, E4))
				mcs:add(m, pair(E4, E4))
			end
		end,

		Jecs = function()
			local j = ecs:entity()
			for i = 1, 100 do
				ecs:add(j, pair(C4, C4))
				ecs:add(j, pair(C4, C4))
			end
		end,
	},
}
