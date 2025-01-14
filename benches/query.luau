--!optimize 2
--!native

local testkit = require("@testkit")
local BENCH, START = testkit.benchmark()
local function TITLE(title: string)
	print()
	print(testkit.color.white(title))
end

local jecs = require("@jecs")
local mirror = require("@mirror")

type i53 = number

do
	TITLE(testkit.color.white_underline("Jecs query"))
	local ecs = jecs.World.new()
	do
		TITLE("one component in common")

		local function view_bench(world: jecs.World, A: i53, B: i53, C: i53, D: i53, E: i53, F: i53, G: i53, H: i53)
			BENCH("1 component", function()
				for _ in world:query(A) do
				end
			end)

			BENCH("2 component", function()
				for _ in world:query(B, A) do
				end
			end)

			BENCH("4 component", function()
				for _ in world:query(D, C, B, A) do
				end
			end)

			BENCH("8 component", function()
				for _ in world:query(H, G, F, E, D, C, B, A) do
				end
			end)

			local e = world:entity()
			world:set(e, A, true)
			world:set(e, B, true)
			world:set(e, C, true)
			world:set(e, D, true)
			world:set(e, E, true)
			world:set(e, F, true)
			world:set(e, G, true)
			world:set(e, H, true)

			BENCH("Update Data", function()
				for _ = 1, 100 do
					world:set(e, A, false)
					world:set(e, B, false)
					world:set(e, C, false)
					world:set(e, D, false)
					world:set(e, E, false)
					world:set(e, F, false)
					world:set(e, G, false)
					world:set(e, H, false)
				end
			end)
		end

		local D1 = ecs:component()
		local D2 = ecs:component()
		local D3 = ecs:component()
		local D4 = ecs:component()
		local D5 = ecs:component()
		local D6 = ecs:component()
		local D7 = ecs:component()
		local D8 = ecs:component()

		local function flip()
			return math.random() >= 0.15
		end

		local added = 0
		local archetypes = {}
		for i = 1, 2 ^ 16 - 2 do
			local entity = ecs:entity()

			local combination = ""

			if flip() then
				combination ..= "B"
				ecs:set(entity, D2, { value = true })
			end
			if flip() then
				combination ..= "C"
				ecs:set(entity, D3, { value = true })
			end
			if flip() then
				combination ..= "D"
				ecs:set(entity, D4, { value = true })
			end
			if flip() then
				combination ..= "E"
				ecs:set(entity, D5, { value = true })
			end
			if flip() then
				combination ..= "F"
				ecs:set(entity, D6, { value = true })
			end
			if flip() then
				combination ..= "G"
				ecs:set(entity, D7, { value = true })
			end
			if flip() then
				combination ..= "H"
				ecs:set(entity, D8, { value = true })
			end

			if #combination == 7 then
				added += 1
				ecs:set(entity, D1, { value = true })
			end
			archetypes[combination] = true
		end

		local a = 0
		for _ in archetypes do
			a += 1
		end

		view_bench(ecs, D1, D2, D3, D4, D5, D6, D7, D8)
	end
end

do
	TITLE(testkit.color.white_underline("Mirror query"))
	local ecs = mirror.World.new()
	do
		TITLE("one component in common")

		local function view_bench(world: jecs.World, A: i53, B: i53, C: i53, D: i53, E: i53, F: i53, G: i53, H: i53)
			BENCH("1 component", function()
				for _ in world:query(A) do
				end
			end)

			BENCH("2 component", function()
				for _ in world:query(B, A) do
				end
			end)

			BENCH("4 component", function()
				for _ in world:query(D, C, B, A) do
				end
			end)

			BENCH("8 component", function()
				for _ in world:query(H, G, F, E, D, C, B, A) do
				end
			end)

			local e = world:entity()
			world:set(e, A, true)
			world:set(e, B, true)
			world:set(e, C, true)
			world:set(e, D, true)
			world:set(e, E, true)
			world:set(e, F, true)
			world:set(e, G, true)
			world:set(e, H, true)

			BENCH("Update Data", function()
				for _ = 1, 100 do
					world:set(e, A, false)
					world:set(e, B, false)
					world:set(e, C, false)
					world:set(e, D, false)
					world:set(e, E, false)
					world:set(e, F, false)
					world:set(e, G, false)
					world:set(e, H, false)
				end
			end)
		end

		local D1 = ecs:component()
		local D2 = ecs:component()
		local D3 = ecs:component()
		local D4 = ecs:component()
		local D5 = ecs:component()
		local D6 = ecs:component()
		local D7 = ecs:component()
		local D8 = ecs:component()

		local function flip()
			return math.random() >= 0.15
		end

		local added = 0
		local archetypes = {}
		for i = 1, 2 ^ 16 - 2 do
			local entity = ecs:entity()

			local combination = ""

			if flip() then
				combination ..= "B"
				ecs:set(entity, D2, { value = true })
			end
			if flip() then
				combination ..= "C"
				ecs:set(entity, D3, { value = true })
			end
			if flip() then
				combination ..= "D"
				ecs:set(entity, D4, { value = true })
			end
			if flip() then
				combination ..= "E"
				ecs:set(entity, D5, { value = true })
			end
			if flip() then
				combination ..= "F"
				ecs:set(entity, D6, { value = true })
			end
			if flip() then
				combination ..= "G"
				ecs:set(entity, D7, { value = true })
			end
			if flip() then
				combination ..= "H"
				ecs:set(entity, D8, { value = true })
			end

			if #combination == 7 then
				added += 1
				ecs:set(entity, D1, { value = true })
			end
			archetypes[combination] = true
		end

		local a = 0
		for _ in archetypes do
			a += 1
		end

		view_bench(ecs, D1, D2, D3, D4, D5, D6, D7, D8)
	end
end
