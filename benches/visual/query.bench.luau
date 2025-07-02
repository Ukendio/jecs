--!optimize 2
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.DevPackages.Matter)
local ecr = require(ReplicatedStorage.DevPackages.ecr)
local newWorld = Matter.World.new()

local jecs = require(ReplicatedStorage.Lib:Clone())
local mirror = require(ReplicatedStorage.mirror:Clone())
local mcs = mirror.world()
local ecs = jecs.world()

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

local registry2 = ecr.registry()

local function flip()
	return math.random() >= 0.25
end

local N = 2 ^ 16 - 2
local archetypes = {}

local hm = 0
for i = 1, N do
	local id = registry2.create()
	local combination = ""
	local n = newWorld:spawn()
	local entity = ecs:entity()
	local m = mcs:entity()

	if flip() then
		registry2:set(id, B1, { value = true })
		ecs:set(entity, D1, { value = true })
		newWorld:insert(n, A1({ value = true }))
		mcs:set(m, E1, { value = 2 })
	end
	if flip() then
		combination ..= "B"
		registry2:set(id, B2, { value = true })
		ecs:set(entity, D2, { value = true })
		mcs:set(m, E2, { value = 2 })
		newWorld:insert(n, A2({ value = true }))
	end
	if flip() then
		combination ..= "C"
		registry2:set(id, B3, { value = true })
		ecs:set(entity, D3, { value = true })
		mcs:set(m, E3, { value = 2 })
		newWorld:insert(n, A3({ value = true }))
	end
	if flip() then
		combination ..= "D"
		registry2:set(id, B4, { value = true })
		ecs:set(entity, D4, { value = true })
		mcs:set(m, E4, { value = 2 })

		newWorld:insert(n, A4({ value = true }))
	end
	if flip() then
		combination ..= "E"
		registry2:set(id, B5, { value = true })
		ecs:set(entity, D5, { value = true })
		mcs:set(m, E5, { value = 2 })

		newWorld:insert(n, A5({ value = true }))
	end
	if flip() then
		combination ..= "F"
		registry2:set(id, B6, { value = true })
		ecs:set(entity, D6, { value = true })
		mcs:set(m, E6, { value = 2 })
		newWorld:insert(n, A6({ value = true }))
	end
	if flip() then
		combination ..= "G"
		registry2:set(id, B7, { value = true })
		ecs:set(entity, D7, { value = true })
		mcs:set(m, E7, { value = 2 })
		newWorld:insert(n, A7({ value = true }))
	end
	if flip() then
		combination ..= "H"
		registry2:set(id, B8, { value = true })
		newWorld:insert(n, A8({ value = true }))
		ecs:set(entity, D8, { value = true })
		mcs:set(m, E8, { value = 2 })
	end

	if combination:find("BCDF") then
		if not archetypes[combination] then
			print(combination)
		end
		hm += 1
	end
	archetypes[combination] = true
end
print("TEST", hm)

local count = 0

for _, archetype in ecs:query(D2, D4, D6, D8):archetypes() do
	count += #archetype.entities
end

print(count)

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
			for entityId, firstComponent in mcs:query(E2, E4, E6, E8) do
			end
		end,

		Jecs = function()
			for entityId, firstComponent in ecs:query(D2, D4, D6, D8) do
			end
		end,
	},
}
