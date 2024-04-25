--!optimize 2
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rgb = require(ReplicatedStorage.rgb)
local Matter = require(ReplicatedStorage.DevPackages.Matter)
local Rewrite = require(ReplicatedStorage.rewrite)
local ecr = require(ReplicatedStorage.DevPackages.ecr)
local newWorld = Matter.World.new()
local world = Rewrite.World.new()
local component = Rewrite.component

local jecs = require(ReplicatedStorage.Lib)
local mirror = require(ReplicatedStorage.mirror)
local mcs = mirror.World.new()
local ecs = jecs.World.new()

local A1 = Matter.component()
local A2 = Matter.component()
local A3 = Matter.component()
local A4 = Matter.component()
local A5 = Matter.component()
local A6 = Matter.component()
local A7 = Matter.component()
local A8 = Matter.component()

local B1 = ecr.component()
local B2 = ecr.component()
local B3 = ecr.component()
local B4 = ecr.component()
local B5 = ecr.component()
local B6 = ecr.component()
local B7 = ecr.component()
local B8 = ecr.component()

local C1 = component()
local C2 = component()
local C3 = component()
local C4 = component()
local C5 = component()
local C6 = component()
local C7 = component()
local C8 = component()

local D1 = ecs:entity()
local D2 = ecs:entity()
local D3 = ecs:entity()
local D4 = ecs:entity()
local D5 = ecs:entity()
local D6 = ecs:entity()
local D7 = ecs:entity()
local D8 = ecs:entity()


local E1 = mcs:entity()
local E2 = mcs:entity()
local E3 = mcs:entity()
local E4 = mcs:entity()
local E5 = mcs:entity()
local E6 = mcs:entity()
local E7 = mcs:entity()
local E8 = mcs:entity()


local registry2 = ecr.registry()

local function flip() 
	return math.random() >= 0.15
end

local common = 0
local N = 2^16-2
local archetypes = {}

local hm = 0
for i = 1, N do 
	local id = registry2.create()
	local combination = ""
	local n = newWorld:spawn()
	local entity = ecs:entity()
	local e = world:spawn()
	local m = mcs:entity()

	if flip() then 
		combination ..= "B"
		registry2:set(id, B2, {value = true}) 
		world:insert(e, C2({ value = true}))
		ecs:set(entity, D2, { value = true})
		mcs:set(m, E2, { value = 2})
		newWorld:insert(n, A2({value = true}))
	end
	if flip() then 
		combination ..= "C"
		registry2:set(id, B3, {value = true}) 
		world:insert(e, C3({ value = true}))
		ecs:set(entity, D3, { value = true})
		mcs:set(m, E3, { value = 2})
		newWorld:insert(n, A3({value = true}))
	end
	if flip() then 
		combination ..= "D"
		registry2:set(id, B4, {value = true}) 
		world:insert(e, C4({ value = true}))
		ecs:set(entity, D4, { value = true})
		mcs:set(m, E4, { value = 2})

		newWorld:insert(n, A4({value = true}))		
	end
	if flip() then 
		combination ..= "E"
		registry2:set(id, B5, {value = true}) 
		world:insert(e, C5({value = true}))
		ecs:set(entity, D5, { value = true})
		mcs:set(m, E5, { value = 2})

		newWorld:insert(n, A5({value = true}))		
	end
	if flip() then 
		combination ..= "F"
		registry2:set(id, B6, {value = true}) 
		world:insert(e, C6({value = true}))
		ecs:set(entity, D6, { value = true})
		mcs:set(m, E6, { value = 2})

		newWorld:insert(n, A6({value = true}))		
	end
	if flip() then 
		combination ..= "G"
		registry2:set(id, B7, {value = true}) 
		world:insert(e, C7{ value = true})
		ecs:set(entity, D7, { value = true})
		mcs:set(m, E7, { value = 2})


		newWorld:insert(n, A7({value = true}))		
	end
	if flip() then 
		combination ..= "H"
		registry2:set(id, B8, {value = true}) 
		world:insert(e, C8{ value = true})
		newWorld:insert(n, A8({value = true}))	
		ecs:set(entity, D8, { value = true})
		mcs:set(m, E8, { value = 2})

	end

	if #combination == 7 then 
		combination = "A" .. combination
		common += 1
		registry2:set(id, B1, {value = true}) 
		world:insert(e, C1{ value = true})
		ecs:set(entity, D1, { value = true})
		newWorld:insert(n, A1({value = true}))	
		mcs:set(m, E1, { value = 2})

	end

	if combination:find("BCDF") then 
		if not archetypes[combination] then 
			 print(combination)
		end 
		hm += 1
	end
	archetypes[combination] = true
end
print("TEST", hm)

local white = rgb.white
local yellow = rgb.yellow
local gray = rgb.gray
local green = rgb.green

local WALL = gray(" │ ")

local numberOfArchetypes = 0
for _  in archetypes do 
	numberOfArchetypes += 1
end
print(common)

print(
	"N entities "..yellow(N)
	..WALL
	.."with common components: "
	..yellow(tostring(common).."/"..tostring(N)).." "
	..yellow("("..string.format("%.2f", (common / (2^16 - 2)* 100)).."%)")
	..WALL
	..yellow("Total Archetypes: "..numberOfArchetypes)
)

return {
	ParameterGenerator = function()
		return
	end,	

	Functions = {
		Mater = function() 
			local matched = 0
			for entityId, firstComponent in newWorld:query(A2, A4, A6, A8) do
				matched += 1
			end
		end,

		ECR = function() 
			local matched = 0
			for entityId, firstComponent in registry2:view(B2, B4, B6, B8) do
				matched += 1
			end
		end,

		Jecs = function() 
			local matched = 0
			for entityId, firstComponent in ecs:query(D2, D4, D6, D8) do
				matched += 1
			end
		

		end,
	},
}
