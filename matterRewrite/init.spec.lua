local Jecs = require(script.Parent)
local component = Jecs.component
local world = Jecs.World.new()

local A, B, C, D = component(), component(), component(), component()
local E, F, G, H = component(), component(), component(), component()
print("A", A)
print("B", B)
print("C", C)
print("D", D)
print("E", E)
print("F", F)
print("G", G)
print("H", H)

for i = 1, 256 do 
	world:spawn(A(true), B(true), C(true), D(true))	

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
			local id = world:spawn(A(true), B(1))

			local id1 = world:spawn(A("hello"))
			expect(world:get(id, A)).to.equal(true)
			expect(world:get(id, B)).to.equal(1)
			expect(world:get(id1, A)).to.equal("hello")
		end)
		it("should remove component", function() 
			local id = world:spawn(A(true), B(1000))
			world:remove(id, A)

			expect(world:get(id, A)).to.equal(nil)
		end)
		it("should override component data", function() 
		
			local id = world:spawn(A(true))
			expect(world:get(id, A)).to.equal(true)

			world:insert(id, A(false))
			expect(world:get(id, A)).to.equal(false)

		end)
		it("query", function()
			local added = 0
			for e, a, b, c, d in world:query(A, B, C, D) do
				added += 1
			end        
			expect(added).to.equal(256)
		end)
		
	end)
end