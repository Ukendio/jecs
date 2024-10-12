local function calculateAverage(times)
	local sum = 0
	for _, time in ipairs(times) do
		sum = sum + time
	end
	return sum / #times
end

-- Main logic to time the test function

local CASES = {
	jecs = function(world, ...)
		for i = 1, 100 do
			local q = world:query(...)
			for _ in q do
			end
		end
	end,
	mirror = function(world, ...)
		for i = 1, 100 do
			local q = world:query(...)
			for _ in q do
			end
		end
	end,
}

for name, fn in CASES do
	local times = {}
	local allocations = {}
	local ecs = require("@" .. name)
	local world = ecs.World.new()
	local A, B, C = world:component(), world:component(), world:component()

	for i = 1, 5 do
		local e = world:entity()
		world:add(e, A)
		world:add(e, B)
		world:add(e, C)
	end

	collectgarbage("collect")
	local count = collectgarbage("count")

	for i = 1, 50000 do
		local startTime = os.clock()
		fn(world, A, B, C)
		local allocated = collectgarbage("count")
		collectgarbage("collect")
		local endTime = os.clock()
		table.insert(times, endTime - startTime)
		table.insert(allocations, allocated)
	end

	print(name, "gc cycle time", calculateAverage(times))
	print(name, "memory allocated", calculateAverage(allocations))
end
