local testkit = require("../testkit")
local jecs = require("../lib/init")
local ecr = require("../DevPackages/_Index/centau_ecr@0.8.0/ecr/src/ecr")


local BENCH, START = testkit.benchmark()

local function TITLE(title: string)
	print()
	print(testkit.color.white(title))
end

local N = 2^16-2

type i53 = number

do TITLE "create"
	BENCH("entity", function()
		local world = jecs.World.new()
		for i = 1, START(N) do
			world:entity()
		end
	end)
end

--- component benchmarks

--todo: perform the same benchmarks for multiple components.?
-- these kind of operations only support 1 component at a time, which is
-- a shame, especially for archetypes where moving components is expensive.

do TITLE "set"
	BENCH("add 1 component", function() 
		local world = jecs.World.new()
		local entities = {}

		local A = world:component()
		
		for i = 1, N do
			entities[i] = world:entity()
		end

		for i = 1, START(N) do
			world:set(entities[i], A, i)
		end
	end)

	BENCH("change 1 component", function() 
		local world = jecs.World.new()
		local entities = {}

		local A = world:component()
		local e = world:entity()
		world:set(e, A, 1)

		for i = 1, START(N) do
			world:set(e, A, 2)
		end
	end)

end

do TITLE "remove"
	BENCH("1 component", function() 
		local world = jecs.World.new()
		local entities = {}

		local A = world:component()
		
		for i = 1, N do
			local id = world:entity()
			entities[i] = id
			world:set(id, A, true)
		end

		for i = 1, START(N) do
			world:remove(entities[i], A)
		end

	end)
end

do TITLE "get"
	BENCH("1 component", function() 
		local world = jecs.World.new()
		local entities = {}

		local A = world:component()

		for i = 1, N do
			local id = world:entity()
			entities[i] = id
			world:set(id, A, true)
		end

		for i = 1, START(N) do
			-- ? curious why the overhead is roughly 80 ns.
			world:get(entities[i], A)
		end

	end)

	BENCH("2 component", function() 
		local world = jecs.World.new()
		local entities = {}

		local A = world:component()
		local B = world:component()
		
		for i = 1, N do
			local id = world:entity()
			entities[i] = id
			world:set(id, A, true)
			world:set(id, B, true)
		end

		for i = 1, START(N) do
			world:get(entities[i], A, B)
		end

	end)

	BENCH("3 component", function() 
		local world = jecs.World.new()
		local entities = {}

		local A = world:component()
		local B = world:component()
		local C = world:component()
		
		for i = 1, N do
			local id = world:entity()
			entities[i] = id
			world:set(id, A, true)
			world:set(id, B, true)
			world:set(id, C, true)
		end

		for i = 1, START(N) do
			world:get(entities[i], A, B, C)
		end

	end)

	BENCH("4 component", function() 
		local world = jecs.World.new()
		local entities = {}

		local A = world:component()
		local B = world:component()
		local C = world:component()
		local D = world:component()
		
		for i = 1, N do
			local id = world:entity()
			entities[i] = id
			world:set(id, A, true)
			world:set(id, B, true)
			world:set(id, C, true)
			world:set(id, D, true)
		end

		for i = 1, START(N) do
			world:get(entities[i], A, B, C, D)
		end

	end)
end

do TITLE (testkit.color.white_underline("Jecs query"))

	local function count(query: () -> ())
		local n = 0
		for _ in query do
			n += 1
		end
		return n
	end

	local function flip()
		return math.random() > 0.5
	end

	local function view_bench(
		world: jecs.World,
		A: i53, B: i53, C: i53, D: i53, E: i53, F: i53, G: i53, H: i53, I: i53
	)

		BENCH("1 component", function()
			START(count(world:query(A)))
			for _ in world:query(A) do end
		end)

		BENCH("2 component", function()
			START(count(world:query(A, B)))
			for _ in world:query(A, B) do end
		end)

		BENCH("4 component", function()
			START(count(world:query(A, B, C, D)))
			for _ in world:query(A, B, C, D) do end
		end)

		BENCH("8 component", function()
			START(count(world:query(A, B, C, D, E, F, G, H)))
			for _ in world:query(A, B, C, D, E, F, G, H) do end
		end)
	end

	do TITLE "random components"

		local world = jecs.World.new()

		local A = world:component()
		local B = world:component()
		local C = world:component()
		local D = world:component()
		local E = world:component()
		local F = world:component()
		local G = world:component()
		local H = world:component()
		local I = world:component()

		for i = 1, N do
			local id = world:entity()
			if flip() then world:set(id, A, true) end
			if flip() then world:set(id, B, true) end
			if flip() then world:set(id, C, true) end
			if flip() then world:set(id, D, true) end
			if flip() then world:set(id, E, true) end
			if flip() then world:set(id, F, true) end
			if flip() then world:set(id, G, true) end
			if flip() then world:set(id, H, true) end
			if flip() then world:set(id, I, true) end
			
		end

		view_bench(world, A, B, C, D, E, F, G, H, I)

	end

	do TITLE "one component in common"

		local world = jecs.World.new()

		local A = world:component()
		local B = world:component()
		local C = world:component()
		local D = world:component()
		local E = world:component()
		local F = world:component()
		local G = world:component()
		local H = world:component()
		local I = world:component()

		for i = 1, N do
			local id = world:entity()
			local a = true
			if flip() then world:set(id, B, true) else a = false end
			if flip() then world:set(id, C, true) else a = false end
			if flip() then world:set(id, D, true) else a = false end
			if flip() then world:set(id, E, true) else a = false end
			if flip() then world:set(id, F, true) else a = false end
			if flip() then world:set(id, G, true) else a = false end
			if flip() then world:set(id, H, true) else a = false end
			if flip() then world:set(id, I, true) else a = false end
			if a then world:set(id, A, true) end
			
		end

		view_bench(world, A, B, C, D, E, F, G, H, I)

	end

end

do TITLE (testkit.color.white_underline("ECR query"))

    local A = ecr.component()
    local B = ecr.component()
    local C = ecr.component()
    local D = ecr.component()
    local E = ecr.component()
    local F = ecr.component()
    local G = ecr.component()
    local H = ecr.component()
    local I = ecr.component()

	local function count(query: () -> ())
		local n = 0
		for _ in query do
			n += 1
		end
		return n
	end

	local function flip()
		return math.random() > 0.5
	end

	local function view_bench(
		world: ecr.Registry,
		A: i53, B: i53, C: i53, D: i53, E: i53, F: i53, G: i53, H: i53, I: i53
	)

		BENCH("1 component", function()
			START(count(world:view(A)))
			for _ in world:view(A) do end
		end)

		BENCH("2 component", function()
			START(count(world:view(A, B)))
			for _ in world:view(A, B) do end
		end)

		BENCH("4 component", function()
			START(count(world:view(A, B, C, D)))
			for _ in world:view(A, B, C, D) do end
		end)

		BENCH("8 component", function()
			START(count(world:view(A, B, C, D, E, F, G, H)))
			for _ in world:view(A, B, C, D, E, F, G, H) do end
		end)
	end


	do TITLE "random components"
        local world = ecr.registry()

		for i = 1, N do
			local id = world.create()
			if flip() then world:set(id, A, true) end
			if flip() then world:set(id, B, true) end
			if flip() then world:set(id, C, true) end
			if flip() then world:set(id, D, true) end
			if flip() then world:set(id, E, true) end
			if flip() then world:set(id, F, true) end
			if flip() then world:set(id, G, true) end
			if flip() then world:set(id, H, true) end
			if flip() then world:set(id, I, true) end
			
		end

		view_bench(world, A, B, C, D, E, F, G, H, I)

	end

	do TITLE "one component in common"

		local world = ecr.registry()

		for i = 1, N do
			local id = world.create()
			local a = true
			if flip() then world:set(id, B, true) else a = false end
			if flip() then world:set(id, C, true) else a = false end
			if flip() then world:set(id, D, true) else a = false end
			if flip() then world:set(id, E, true) else a = false end
			if flip() then world:set(id, F, true) else a = false end
			if flip() then world:set(id, G, true) else a = false end
			if flip() then world:set(id, H, true) else a = false end
			if flip() then world:set(id, I, true) else a = false end
			if a then world:set(id, A, true) end
			
		end

		view_bench(world, A, B, C, D, E, F, G, H, I)

	end

end