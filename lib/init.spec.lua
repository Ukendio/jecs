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
	ecs:add(entity, A, true) 
	ecs:add(entity, B, true)
	ecs:add(entity, C, true)
	ecs:add(entity, D, true)

	--[[
	ecs:add(entity, E, true)
	ecs:add(entity, F, true)
	ecs:add(entity, G, true)
	ecs:add(entity, H, true)
	print("end")
	]]
end

return function()
	describe("World", function()
		it("should add component", function()
			local id = ecs:entity()
			ecs:add(id, A, true)
			ecs:add(id, B, 1)

			local id1 = ecs:entity()
			ecs:add(id1, A, "hello")
			expect(ecs:get(id, A)).to.equal(true)
			expect(ecs:get(id, B)).to.equal(1)
			expect(ecs:get(id1, A)).to.equal("hello")
		end)
		it("should remove component", function() 
			local id = ecs:entity()
			ecs:add(id, A, true)
			ecs:add(id, B, 1000)
			ecs:remove(id, A, false)

			expect(ecs:get(id, A)).to.equal(nil)
		end)
		it("should override component data", function() 
		
			local id = ecs:entity()
			ecs:add(id, A, true)
			expect(ecs:get(id, A)).to.equal(true)

			ecs:add(id, A, false)
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