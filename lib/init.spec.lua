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

for i = 1, 256 do 
	local entity = ecs:entity()
	ecs:set(entity, A, true) 
	ecs:set(entity, B, true)
	ecs:set(entity, C, true)
	ecs:set(entity, D, true)

	--[[
	ecs:set(entity, E, true)
	ecs:set(entity, F, true)
	ecs:set(entity, G, true)
	ecs:set(entity, H, true)
	print("end")
	]]
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
			for e, a, b, c, d in ecs:query(A, B, C, D) do
				added += 1
			end        
			expect(added).to.equal(256)
		end)
		
	end)
end