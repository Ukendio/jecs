local jecs = require("../src/init")

local testkit = require("../testkit")

local BENCH, START = testkit.benchmark()

local function TITLE(s: string)
	print()
	print(testkit.color.white(s))
end

local N = 2^18

local pair = jecs.pair

do TITLE "create"
	local world = jecs.World.new()

	BENCH("entity", function()
		for i = 1, START(N) do
			world:entity()
		end
	end)

	local A, B = world:entity(), world:entity()

	BENCH("pair", function()
		for i = 1, START(N) do
			jecs.pair(A, B)
		end
	end)

end

do TITLE "set"

	local world = jecs.World.new()
	local A = world:entity()

	local entities = table.create(N)

	for i = 1, N do
		entities[i] = world:entity()
	end

	BENCH("add", function()
		for i = 1, START(N) do
			world:set(entities[i], A, 1)
		end
	end)

	BENCH("set", function()
		for i = 1, START(N) do
			world:set(entities[i], A, 2)
		end
	end)
end

do TITLE "get"

	local world = jecs.World.new()
	local A, B, C, D = world:entity(), world:entity(), world:entity(), world:entity()

	local entities = table.create(N)

	for i = 1, N do
		entities[i] = world:entity()
		world:set(entities[i], A, 1)
		world:set(entities[i], B, 1)
		world:set(entities[i], C, 1)
		world:set(entities[i], D, 1)
	end

	BENCH("1", function()
		for i = 1, START(N) do
			world:get(entities[i], A)
		end
	end)

	BENCH("2", function()
		for i = 1, START(N) do
			world:get(entities[i], A, B)
		end
	end)

	BENCH("3", function()
		for i = 1, START(N) do
			world:get(entities[i], A, B, C)
		end
	end)

	BENCH("4", function()
		for i = 1, START(N) do
			world:get(entities[i], A, B, C, D)
		end
	end)
end