--!optimize 2
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rgb = require(ReplicatedStorage.rgb)
local Matter = require(ReplicatedStorage.DevPackages.Matter)
local jecs = require(ReplicatedStorage.Lib)
local ecr = require(ReplicatedStorage.DevPackages.ecr)
local newWorld = Matter.World.new()
local ecs = jecs.World.new()
local mirror = require(ReplicatedStorage.mirror)

local mcs = mirror.World.new()

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

local N = 2^16-2
local archetypes = {}
local entities = {
    jecs = {},
    ecr = {},
    matter = {},
    mirror = {}
}
local common = 0
for i = 1, N do 
	local combination = 0
	local id = registry2.create()
	local n = newWorld:spawn()
	local entity = ecs:entity()
    local m = mcs:entity()

    if flip() then 
		combination ..= "B"
		registry2:set(id, B2, {value = true}) 
		ecs:set(entity, D2, { value = true})
		mcs:set(m, E2, { value = true})
		newWorld:insert(n, A2({value = true}))
	end
	if flip() then 
		combination ..= "C"
		registry2:set(id, B3, {value = true}) 
		ecs:set(entity, D3, { value = true})
		mcs:set(m, E3, { value = true})
		newWorld:insert(n, A3({value = true}))
	end
	if flip() then 
		combination ..= "D"
		registry2:set(id, B4, {value = true}) 
		ecs:set(entity, D4, { value = true})
		mcs:set(m, E4, { value = true})

		newWorld:insert(n, A4({value = true}))		
	end
	if flip() then 
		combination ..= "E"
		registry2:set(id, B5, {value = true}) 
		ecs:set(entity, D5, { value = true})
		mcs:set(m, E5, { value = true})

		newWorld:insert(n, A5({value = true}))		
	end
	if flip() then 
		combination ..= "F"
		registry2:set(id, B6, {value = true}) 
		ecs:set(entity, D6, { value = true})
		mcs:set(m, E6, { value = true})
		newWorld:insert(n, A6({value = true}))		
	end
	if flip() then 
		combination ..= "G"
		registry2:set(id, B7, {value = true}) 
		ecs:set(entity, D7, { value = true})
		mcs:set(m, E7, { value = true})
		newWorld:insert(n, A7({value = true}))		
	end
	if flip() then 
		combination ..= "H"
		registry2:set(id, B8, {value = true}) 
		newWorld:insert(n, A8({value = true}))	
		ecs:set(entity, D8, { value = true})
		mcs:set(m, E8, { value = true})

	end
	if #combination == 7 then 
		registry2:set(id, B1, {value = true}) 
		ecs:set(entity, D1, { value = true})
		newWorld:insert(n, A1({value = true}))	
        mcs:set(m, E1, { value = true})
        common += 1
        table.insert(entities.ecr, id)
        table.insert(entities.jecs, entity)
        table.insert(entities.matter, n)
        table.insert(entities.mirror, m)

	end
	archetypes[combination] = true
end


local jecsEnt = entities.jecs
local ecrEnt = entities.ecr
local matEnt = entities.matter
local mirEnt = entities.mirror

return {
	ParameterGenerator = function()
		return
	end,

	Functions = {
		Matter = function() 
            for i = 1, 500 do 
                newWorld:get(matEnt[math.random(1, common)], A1, A2, A3)
            end
		end,

		Jecs = function() 
            for i = 1, 500 do 
                ecs:get(jecsEnt[math.random(1, common)], D1, D2, D3)
            end
		end,

        Mirror = function() 
            for i = 1, 500 do 
                ecs:get(mirEnt[math.random(1, common)], E1, E2, E3)
            end
		end
	},
}
