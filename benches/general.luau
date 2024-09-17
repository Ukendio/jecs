local jecs = require("@jecs")
local testkit = require("@testkit")

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

-- we have a separate benchmark for relationships.
-- this is due to that relationships have a very high id compared to normal
-- components, which cause them to get added into the hashmap portion.
do TITLE "set relationship"

	local world = jecs.World.new()
	local A = world:entity()

	local entities = table.create(N)

	for i = 1, N do
		entities[i] = world:entity()
		world:set(entities[i], A, 1)
	end

	local pair = jecs.pair(A, world:entity())

	BENCH("add", function()
		for i = 1, START(N) do
			world:set(entities[i], pair, 1)
		end
	end)

	BENCH("set", function()
		for i = 1, START(N) do
			world:set(entities[i], pair, 2)
		end
	end)

	BENCH("remove", function()
		for i = 1, START(N) do
			world:remove(entities[i], pair)
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

do TITLE "target"

	BENCH("1st target", function()
		local world = jecs.World.new()
		local A, B, C, D = world:entity(), world:entity(), world:entity(), world:entity()
		local entities = table.create(N)

		for i = 1, N do
			local ent = world:entity()
			entities[i] = ent

			world:set(ent, pair(A, A))
			world:set(ent, pair(A, B))
			world:set(ent, pair(A, C))
			world:set(ent, pair(A, D))
		end

		for i = 1, START(N) do
			world:target(entities[i], A, 0)
		end
	end)

end

--- this benchmark is used to view how fragmentation affects query performance
--- we use this by determining how many entities should fit per arcehtype, instead
--- of creating x amount of archetypes. this would scale better with any amount of
--- entities.
do TITLE(`query {N} entities`)

	local function view_bench(n: number)
		BENCH(`{n} entities per archetype`, function()
			local world = jecs.World.new()
			local A = world:component()
			local B = world:component()
			local C = world:component()
			local D = world:component()

			for i = 1, N, n do
				local ct = world:entity()
				for j = 1, n do
					local id = world:entity()
					world:set(id, A, true)
					world:set(id, B, true)
					world:set(id, C, true)
					world:set(id, D, true)
					world:set(id, ct, true)
				end
			end


			START()
			for id in world:query(A, B, C, D) do
			end
		end)

		BENCH(`inlined query`, function()
		    local world = jecs.World.new()
			local A = world:component()
			local B = world:component()
			local C = world:component()
			local D = world:component()

			for i = 1, N, n do
				local ct = world:entity()
				for j = 1, n do
					local id = world:entity()
					world:set(id, A, true)
					world:set(id, B, true)
					world:set(id, C, true)
					world:set(id, D, true)
					world:set(id, ct, true)
				end
			end


			START()
			for _, archetype in world:query(A, B, C, D):archetypes() do
			    local columns, records = archetype.columns, archetype.records
				local a = columns[records[A].column]
				local b = columns[records[B].column]
				local c = columns[records[C].column]
				local d = columns[records[D].column]
			    for row in archetype.entities do
					local _1, _2, _3, _4 = a[row], b[row], c[row], d[row]
				end
			end
		end)
	end

	for i = 13, 0, -1 do
		view_bench(2^i)
	end

end
