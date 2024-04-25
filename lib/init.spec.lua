local ecs = require(script.Parent).World.new()

local A, B, C, D = ecs:entity(), ecs:entity(), ecs:entity(), ecs:entity()
local E, F, G, H = ecs:entity(), ecs:entity(), ecs:entity(), ecs:entity()
print("A", A)
print("B", B)
print("C", C)
print("D", D)
print("E", E)
print("F", F)
print("G", G)
print("H", H)

local common = 0
local N = 2^16-2
local archetypes = {}
local function flip() 
	return math.random() >= 0.5
end

local hm = 0
for i = 1, N do 
	local entity = ecs:entity()
	local combination = ""

	if flip() then 
		combination ..= "2_"
		ecs:set(entity, B, { value = true})
	end
	if flip() then 
		combination ..= "3_"
		ecs:set(entity, C, { value = true})
	end
	if flip() then 
		combination ..= "4_"
		ecs:set(entity, D, { value = true})
	end
	if flip() then 
		combination ..= "5_"
		ecs:set(entity, E, { value = true})
	end
	if flip() then 
		combination ..= "6_"
		ecs:set(entity, F, { value = true})
	end
	if flip() then 
		combination ..= "7_"
		ecs:set(entity, G, { value = true})
	end
	if flip() then 
		combination ..= "8"
		ecs:set(entity, H, { value = true})
	end

	if #combination == 7 then 
		combination = "1_" .. combination
		common += 1
		ecs:set(entity, A, { value = true})
	end

	if combination:find("2") 
		and combination:find("3") 
		and combination:find("4")
		and combination:find("6")
	then 
		hm += 1
	end
	archetypes[combination] = true
end


local arch = 0
for combination in archetypes do 
	if combination:find("2") 
		and combination:find("3") 
		and combination:find("4")
		and combination:find("6")
	then 
		arch += 1
	end
end
return function()
	describe("World", function()
		it("should add component", function()
			local id = ecs:entity()
			ecs:set(id, A, true)
			ecs:set(id, B, 1)

			local id1 = ecs:entity()
			ecs:set(id1, A, "hello")
			expect(ecs:get(id, A)).to.equal(true)
			expect(ecs:get(id, B)).to.equal(1)
			expect(ecs:get(id1, A)).to.equal("hello")
		end)
		it("should remove component", function() 
			local id = ecs:entity()
			ecs:set(id, A, true)
			ecs:set(id, B, 1000)
			ecs:remove(id, A, false)

			expect(ecs:get(id, A)).to.equal(nil)
		end)
		it("should override component data", function() 
		
			local id = ecs:entity()
			ecs:set(id, A, true)
			expect(ecs:get(id, A)).to.equal(true)

			ecs:set(id, A, false)
			expect(ecs:get(id, A)).to.equal(false)

		end)
		it("query", function()
			local added = 0
			for _ in ecs:query(B, C, D, F) do
				added += 1
			end        
			expect(added).to.equal(hm)
			print(added, hm)
		end)
		
	end)
end