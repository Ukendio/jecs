--!optimize 2
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rgb = require(ReplicatedStorage.rgb)
local Matter = require(ReplicatedStorage.DevPackages.Matter)
local jecs = require(ReplicatedStorage.Lib)
local ecr = require(ReplicatedStorage.DevPackages.ecr)
local newWorld = Matter.World.new()
local ecs = jecs.World.new()


return {
	ParameterGenerator = function()
        local registry2 = ecr.registry()

		return registry2
	end,

	Functions = {
		Matter = function() 
            for i = 1, 1000 do 
               newWorld:spawn()             
            end
		end,


		ECR = function(_, registry2) 
            for i = 1, 1000 do
                registry2.create()
            end
		end,


		Jecs = function() 
            for i = 1, 1000 do 
                ecs:entity()
            end
		end

	},
}
