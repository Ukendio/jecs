--!optimize 2
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local jecs = require(ReplicatedStorage.Lib:Clone())
local chrono = require(ReplicatedStorage.chronoecs:Clone())
local ecs = jecs.world()
local ccs = chrono.new()

local D1 = ecs:component()
local D2 = ecs:component()
local D3 = ecs:component()
local D4 = ecs:component()
local D5 = ecs:component()
local D6 = ecs:component()
local D7 = ecs:component()
local D8 = ecs:component()

local E1 = ccs:component()
local E2 = ccs:component()
local E3 = ccs:component()
local E4 = ccs:component()
local E5 = ccs:component()
local E6 = ccs:component()
local E7 = ccs:component()
local E8 = ccs:component()

local d_components = {}
local e_components = {}

for i = 1, 150 do
	ecs:component()
	ccs:component()
end

local function flip()
	return math.random() >= 0.5
end

local N = 2 ^ 16 - 2

for i = 1, N do
	local entity = ecs:entity()
	local m = ccs:entity()

	if flip() then
		ecs:set(entity, D1, true)
		ccs:add(m, E1)
		ccs:set(m, E1, true)
	end
	if flip() then
		ecs:set(entity, D2, true)
		ccs:add(m, E2)
		ccs:set(m, E2, true)
	end
	if flip() then
		ecs:set(entity, D3, true)
		ccs:add(m, E3)
		ccs:set(m, E3, true)
	end
	if flip() then
		ecs:set(entity, D4, true)
		ccs:add(m, E4)
		ccs:set(m, E4, true)
	end
	if flip() then
		ecs:set(entity, D5, true)
		ccs:add(m, E4)
		ccs:set(m, E5, true)
	end
	if flip() then
		ecs:set(entity, D6, true)
		ccs:add(m, E6)
		ccs:set(m, E6, true)
	end
	if flip() then
		ecs:set(entity, D7, true)
		ccs:add(m, E7)
		ccs:set(m, E7, true)
	end
	if flip() then
		ccs:add(m, E8)
		ecs:set(entity, D8, true)
		ccs:set(m, E8, true)
	end
end

return {
	ParameterGenerator = function()
		return
	end,

	Functions = {
		-- Matter = function()
		-- 	for entityId, firstComponent in newWorld:query(A2, A4, A6, A8) do
		-- 	end
		-- end,

		-- ECR = function()
		-- 	for entityId, firstComponent in registry2:view(B2, B4, B6, B8) do
		-- 	end
		-- end,
		--
		chrono = function()
			for entityId, firstComponent in ccs:view(E2, E4, E6, E8) do
			end
		end,

		Jecs = function()
			for entityId, firstComponent in ecs:query(D2, D4, D6, D8) do
			end
		end,
	},
}
