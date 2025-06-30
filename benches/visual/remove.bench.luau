--!optimize 2
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.DevPackages.Matter)
local ecr = require(ReplicatedStorage.DevPackages.ecr)
local jecs = require(ReplicatedStorage.Lib)
local pair = jecs.pair
local ecs = jecs.world()
local mirror = require(ReplicatedStorage.mirror)
local mcs = mirror.world()

local C1 = ecs:component()
local C2 = ecs:entity()
ecs:add(C2, pair(jecs.OnDeleteTarget, jecs.Delete))
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
			for i = 1, 1000 do
				mcs:add(m, E3)
				mcs:remove(m, E3)
			end
		end,

		Jecs = function()
			local j = ecs:entity()
			for i = 1, 1000 do
				ecs:add(j, C3)
				ecs:remove(j, C3)
			end
		end,
	},
}
