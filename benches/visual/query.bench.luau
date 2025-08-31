--!optimize 2
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local jecs = require(ReplicatedStorage.Lib:Clone())
local mirror = require(ReplicatedStorage.mirror:Clone())
local mcs = mirror.world()
local ecs = jecs.world()

local D1 = ecs:component()
local D2 = ecs:component()
local D3 = ecs:component()
local D4 = ecs:component()
local D5 = ecs:component()
local D6 = ecs:component()
local D7 = ecs:component()
local D8 = ecs:component()

local E1 = mcs:component()
local E2 = mcs:component()
local E3 = mcs:component()
local E4 = mcs:component()
local E5 = mcs:component()
local E6 = mcs:component()
local E7 = mcs:component()
local E8 = mcs:component()

local function flip()
	return math.random() >= 0.3
end

local N = 2 ^ 16 - 2

for i = 1, N do
	local entity = ecs:entity()
	local m = mcs:entity()

	if flip() then
		ecs:add(entity, entity)
		mcs:add(m, m)
	end
	if flip() then
		ecs:set(entity, D1, true)
		mcs:set(m, E1, true)
	end
	if flip() then
		ecs:set(entity, D2, true)
		mcs:set(m, E2, true)
	end
	if flip() then
		ecs:set(entity, D3, true)
		mcs:set(m, E3, true)
	end
	if flip() then
		ecs:set(entity, D4, true)
		mcs:set(m, E4, true)
	end
	if flip() then
		ecs:set(entity, D5, true)
		mcs:set(m, E5, true)
	end
	if flip() then
		ecs:set(entity, D6, true)
		mcs:set(m, E6, true)
	end
	if flip() then
		ecs:set(entity, D7, true)
		mcs:set(m, E7, true)
	end
	if flip() then
		ecs:set(entity, D8, true)
		mcs:set(m, E8, true)
	end
end

local count = 0

for _, archetype in ecs:query(D2, D4, D6, D8):archetypes() do
	count += #archetype.entities
end


local mq = mcs:query(E2, E4, E6, E8):cached()
local jq = ecs:query(D2, D4, D6, D8):cached()

print(count, #jq:archetypes())

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
		Mirror = function()
			for entityId, firstComponent in mq do
			end
		end,

		Jecs = function()
			for entityId, firstComponent in jq do
			end
		end,
	},
}
