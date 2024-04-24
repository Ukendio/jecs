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


local registry2 = ecr.registry()

local function flip() 
	return math.random() >= 0.15
end

local common = 0
local N = 2^16-2
local archetypes = {}
for i = 1, N do 
	local id = registry2.create()
	local combination = ""
	local n = newWorld:spawn()
	local entity = ecs:entity()
	local e = world:spawn()

	if flip() then 
		combination ..= "B"
		registry2:set(id, B2, {value = true}) 
		world:insert(e, C2({ value = true}))
		ecs:set(entity, D2, { value = true})
		newWorld:insert(n, A2({value = true}))
	end
	if flip() then 
		combination ..= "C"
		registry2:set(id, B3, {value = true}) 
		world:insert(e, C3({ value = true}))
		ecs:set(entity, D3, { value = true})
		newWorld:insert(n, A3({value = true}))
	end
	if flip() then 
		combination ..= "D"
		registry2:set(id, B4, {value = true}) 
		world:insert(e, C4({ value = true}))
		ecs:set(entity, D4, { value = true})
		newWorld:insert(n, A4({value = true}))		
	end
	if flip() then 
		combination ..= "E"
		registry2:set(id, B5, {value = true}) 
		world:insert(e, C5({value = true}))
		ecs:set(entity, D5, { value = true})
		newWorld:insert(n, A5({value = true}))		
	end
	if flip() then 
		combination ..= "F"
		registry2:set(id, B6, {value = true}) 
		world:insert(e, C6({value = true}))
		ecs:set(entity, D6, { value = true})
		newWorld:insert(n, A6({value = true}))		
	end
	if flip() then 
		combination ..= "G"
		registry2:set(id, B7, {value = true}) 
		world:insert(e, C7{ value = true})
		ecs:set(entity, D7, { value = true})

		newWorld:insert(n, A7({value = true}))		
	end
	if flip() then 
		combination ..= "H"
		registry2:set(id, B8, {value = true}) 
		world:insert(e, C8{ value = true})
		newWorld:insert(n, A8({value = true}))	
		ecs:set(entity, D8, { value = true})
	
	end

	if #combination == 7 then 
		combination = "A" .. combination
		common += 1
		registry2:set(id, B1, {value = true}) 
		world:insert(e, C1{ value = true})
		ecs:set(entity, D1, { value = true})
		newWorld:insert(n, A1({value = true}))	
	end

	archetypes[combination] = true
end

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
		ECR = function() 
			local matched = 0
			for entityId, firstComponent in registry2:view(B5, B6, B3, B4, B8, B7) do
				matched += 1
			end
		end,

		Rewrite = function() 
			local matched = 0
			for entityId, firstComponent in world:query(C5, C6, C3, C4, C8, C7) do
				matched += 1
			end
		end,

		Jecs = function() 
			local matched = 0
			for entityId, firstComponent in ecs:query(D5, D6, D3, D4, D8, D7) do
				matched += 1
			end
		end

	},
}
