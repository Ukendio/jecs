--!optimize 2
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local C1 = ecs:entity()
local C2 = ecs:entity()
local C3 = ecs:entity()
local C4 = ecs:entity()
local C5 = ecs:entity()
local C6 = ecs:entity()
local C7 = ecs:entity()
local C8 = ecs:entity()
local E1 = mcs:entity()
local E2 = mcs:entity()
local E3 = mcs:entity()
local E4 = mcs:entity()
local E5 = mcs:entity()
local E6 = mcs:entity()
local E7 = mcs:entity()
local E8 = mcs:entity()


local registry2 = ecr.registry()
return {
	ParameterGenerator = function()
		return
	end,

	Functions = {
		Matter = function() 
            for i = 1, 500 do 
               newWorld:spawn(
                    A1({ value = true }),
                    A2({ value = true }),
                    A3({ value = true }),
                    A4({ value = true }),
                    A5({ value = true }),
                    A6({ value = true }),
                    A7({ value = true }),
                    A8({ value = true })
                )             
            end
		end,


		ECR = function() 
            local e = registry2.create()
            for i = 1, 500 do
                registry2:set(e, B1, {value = false}) 
                registry2:set(e, B2, {value = false}) 
                registry2:set(e, B3, {value = false}) 
                registry2:set(e, B4, {value = false}) 
                registry2:set(e, B5, {value = false}) 
                registry2:set(e, B6, {value = false}) 
                registry2:set(e, B7, {value = false}) 
                registry2:set(e, B8, {value = false})
            end
		end,


		Jecs = function() 

            local e = ecs:entity()
            
            for i = 1, 500 do 

                ecs:set(e, C1, {value = false}) 
                ecs:set(e, C2, {value = false}) 
                ecs:set(e, C3, {value = false}) 
                ecs:set(e, C4, {value = false}) 
                ecs:set(e, C5, {value = false}) 
                ecs:set(e, C6, {value = false}) 
                ecs:set(e, C7, {value = false}) 
                ecs:set(e, C8, {value = false}) 

            end
		end,
        Mirror = function() 

            local e = ecs:entity()
            
            for i = 1, 500 do 

                mcs:set(e, E1, {value = false}) 
                mcs:set(e, E2, {value = false}) 
                mcs:set(e, E3, {value = false}) 
                mcs:set(e, E4, {value = false}) 
                mcs:set(e, E5, {value = false}) 
                mcs:set(e, E6, {value = false}) 
                mcs:set(e, E7, {value = false}) 
                mcs:set(e, E8, {value = false}) 

            end
		end

	},
}
