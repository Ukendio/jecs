local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
_G.__JECS_HI_COMPONENT_ID = 300
local ecs = require(ReplicatedStorage.ecs)

-- 500 entities
-- 2-30 components on each entity
-- 300 unique components
-- 200 systems
-- 1-10 components to query per system

local startTime = os.clock()

local world = ecs.World.new()

local components = {}

for i = 1, 300 do -- 300 components
	components[i] = world:component()
end

local archetypes = {}
for i = 1, 50 do -- 50 archetypes
	local archetype = {}

	for _ = 1, math.random(2, 30) do
		local componentId = math.random(1, #components)

		table.insert(archetype, components[componentId])
	end

	archetypes[i] = archetype
end

for _ = 1, 1000 do -- 1000 entities in the world
	local componentsToAdd = {}

	local archetypeId = math.random(1, #archetypes)
	local e = world:entity()
	for _, component in ipairs(archetypes[archetypeId]) do
		world:set(e, component, {
			DummyData = math.random(1, 5000),
		})
	end
end

local function values(t)
	local array = {}
	for _, v in t do
		table.insert(array, v)
	end
	return array
end

local contiguousComponents = values(components)
local systemComponentsToQuery = {}

for _ = 1, 200 do -- 200 systems
	local numComponentsToQuery = math.random(1, 10)
	local componentsToQuery = {}

	for _ = 1, numComponentsToQuery do
		table.insert(componentsToQuery, contiguousComponents[math.random(1, #contiguousComponents)])
	end

	table.insert(systemComponentsToQuery, componentsToQuery)
end

local worldCreateTime = os.clock() - startTime
local results = {}
startTime = os.clock()

RunService.Heartbeat:Connect(function()
	local added = 0
	local systemStartTime = os.clock()
	debug.profilebegin("systems")
	for _, componentsToQuery in ipairs(systemComponentsToQuery) do
		debug.profilebegin("system")
		for entityId, firstComponent in world:query(unpack(componentsToQuery)) do
			world:set(
				entityId,
				{
					DummyData = firstComponent.DummyData + 1,
				}
			)
			added += 1
		end
		debug.profileend()
	end
	debug.profileend()

	if os.clock() - startTime < 4 then
		-- discard first 4 seconds
		return
	end

	if results == nil then
		return
	elseif #results < 1000 then
		table.insert(results, os.clock() - systemStartTime)
	else
		print("added", added)
		print("World created in", worldCreateTime * 1000, "ms")
		local sum = 0
		for _, result in ipairs(results) do
			sum += result
		end
		print(("Average frame time: %fms"):format((sum / #results) * 1000))

		results = nil

		local n = #world.archetypes

		print(
			("X entities\n%d components\n%d systems\n%d archetypes"):format(
				#components,
				#systemComponentsToQuery,
				n
			)
		)
	end
end)
