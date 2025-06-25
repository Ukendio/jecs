--!optimize 2
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.DevPackages.Matter)
local ecr = require(ReplicatedStorage.DevPackages.ecr)
local jecs = require(ReplicatedStorage.Lib)
local pair = jecs.pair
local ecs = jecs.world()
local mirror = require(ReplicatedStorage.mirror)
local mcs = mirror.World.new()

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
		local j = ecs:entity()
		ecs:set(j, C1, true)
		local m = mcs:entity()
		mcs:set(m, E1, true)
		for i = 1, 1000 do
			local friend1 = ecs:entity()
			local friend2 = mcs:entity()

			ecs:add(friend1, pair(C2, j))
			ecs:add(friend1, pair(C3, j))
			ecs:add(friend1, pair(C4, j))

			mcs:add(friend2, pair(E2, m))
			mcs:add(friend2, pair(E3, m))
			mcs:add(friend2, pair(E4, m))
		end
		return {
			m = m,
			j = j,
		}
	end,

	Functions = {
		Mirror = function(_, a)
			mcs:delete(a.m)
		end,

		Jecs = function(_, a)
			ecs:delete(a.j)
		end,
	},
}
