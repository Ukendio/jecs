local jecs = require("../src/init")

local testkit = require("../testkit")

local BENCH, START = testkit.benchmark()

local function TITLE(s: string)
	print()
	print(testkit.color.white(s))
end

local N = 2^17

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

	BENCH("remove", function()
		for i = 1, START(N) do
			world:remove(entities[i], A)
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

--- this benchmark is used to view how fragmentation affects query performance
--- we use this by determining how many entities should fit per arcehtype, instead
--- of creating x amount of archetypes. this would scale better with any amount of
--- entities.
do TITLE(`query {N} entities`)

	local function view_bench(world: jecs.WorldShim, A: jecs.Entity, B: jecs.Entity, C: jecs.Entity, D: jecs.Entity)

		BENCH("1 component", function()
			for id in world:query(A) do

			end
		end)

		BENCH("2 component", function()
			for id in world:query(A, B) do

			end
		end)

		BENCH("3 component", function()
			for id in world:query(A, B, C) do

			end
		end)

		BENCH("4 component", function()
			for id in world:query(A, B, C, D) do

			end
		end)

	end

	do TITLE "2048 entities per archetype"
		local world = jecs.World.new()
		local A, B, C, D = world:entity(), world:entity(), world:entity(), world:entity()

		for i = 1, N, 2048 do
			local ct = world:entity()
			for j = 1, 2048 do
				local id = world:entity()
				world:set(id, A, true)
				world:set(id, B, true)
				world:set(id, C, true)
				world:set(id, D, true)
				world:set(id, ct, true)
			end
		end

		view_bench(world, A, B, C, D)
	end

	do TITLE "512 entities per archetype"
		local world = jecs.World.new()
		local A, B, C, D = world:entity(), world:entity(), world:entity(), world:entity()

		for i = 1, N, 512 do
			local ct = world:entity()
			for j = 1, 512 do
				local id = world:entity()
				world:set(id, A, true)
				world:set(id, B, true)
				world:set(id, C, true)
				world:set(id, D, true)
				world:set(id, ct, true)
			end
		end

		view_bench(world, A, B, C, D)
	end

	do TITLE "32 entities per archetype"
		local world = jecs.World.new()
		local A, B, C, D = world:entity(), world:entity(), world:entity(), world:entity()

		for i = 1, N, 32 do
			local ct = world:entity()
			for j = 1, 32 do
				local id = world:entity()
				world:set(id, A, true)
				world:set(id, B, true)
				world:set(id, C, true)
				world:set(id, D, true)
				world:set(id, ct, true)
			end
		end

		view_bench(world, A, B, C, D)
	end

	do TITLE "16 entities per archetype"
		local world = jecs.World.new()
		local A, B, C, D = world:entity(), world:entity(), world:entity(), world:entity()

		for i = 1, N, 16 do
			local ct = world:entity()
			for j = 1, 16 do
				local id = world:entity()
				world:set(id, A, true)
				world:set(id, B, true)
				world:set(id, C, true)
				world:set(id, D, true)
				world:set(id, ct, true)
			end
		end

		view_bench(world, A, B, C, D)
	end

	do TITLE "8 entity per archetype"
		local world = jecs.World.new()
		local A, B, C, D = world:entity(), world:entity(), world:entity(), world:entity()

		for i = 1, N, 8 do
			local ct = world:entity()
			for j = 1, 8 do
				local id = world:entity()
				world:set(id, A, true)
				world:set(id, B, true)
				world:set(id, C, true)
				world:set(id, D, true)
				world:set(id, ct, true)
			end
		end

		view_bench(world, A, B, C, D)
	end

	do TITLE "archetype per entity"
		local world = jecs.World.new()
		local A, B, C, D = world:entity(), world:entity(), world:entity(), world:entity()

		for i = 1, N do
			local id = world:entity()
			world:set(id, A, true)
			world:set(id, B, true)
			world:set(id, C, true)
			world:set(id, D, true)
			world:set(id, pair(A, id))
		end

		view_bench(world, A, B, C, D)
	end

end
