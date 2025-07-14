
--!optimize 2
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Lib:Clone())
local pair = jecs.pair
local ecs = jecs.world()
local mirror = require(ReplicatedStorage.mirror:Clone())
local mcs = mirror.world()

local C1 = ecs:component()
local C2 = ecs:entity()
local C3 = ecs:entity()
local C4 = ecs:entity()
local E1 = mcs:component()
local E2 = mcs:entity()
local E3 = mcs:entity()
local E4 = mcs:entity()

local m = mcs:entity()
local j = ecs:entity()

return {
	ParameterGenerator = function()
	end,

	Functions = {
		Mirror = function()
			for i = 1, 10 do
				local friend2 = mcs:entity()
				mcs:add(friend2, pair(E2, m))
				mcs:add(friend2, pair(E3, m))
				mcs:add(friend2, pair(E4, m))

				-- local r = mirror.entity_index_try_get_fast(mcs.entity_index, friend2)
				-- local archetype = r.archetype

				-- mirror.archetype_destroy(mcs, archetype)

				mcs:delete(m)
				m = mcs:entity(m)
			end

		end,

		Jecs = function()
			for i = 1, 10 do
				local friend1 = ecs:entity()
				ecs:add(friend1, pair(C2, j))
				ecs:add(friend1, pair(C3, j))
				ecs:add(friend1, pair(C4, j))

				-- local r = jecs.entity_index_try_get_fast(ecs.entity_index, friend1)
				-- local archetype = r.archetype

				-- jecs.archetype_destroy(ecs, archetype)

				ecs:delete(j)
				j = ecs:entity()
			end

		end,
	},
}
