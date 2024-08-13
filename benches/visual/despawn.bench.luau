--!optimize 2
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.DevPackages.Matter)
local ecr = require(ReplicatedStorage.DevPackages.ecr)
local jecs = require(ReplicatedStorage.Lib)
local rgb = require(ReplicatedStorage.rgb)
local newWorld = Matter.World.new()
local ecs = jecs.World.new()

local A, B = Matter.component(), Matter.component()
local C, D = ecs:component(), ecs:component()


return {
	ParameterGenerator = function()
    	local matter_entities = {}
        local jecs_entities = {}
        local entities = {
            matter = matter_entities,
            jecs = jecs_entities
        }
        for i = 1, 1000 do
            table.insert(matter_entities, newWorld:spawn(A(), B()))
            local e = ecs:entity()
            ecs:set(e, C, {})
            ecs:set(e, D, {})
            table.insert(jecs_entities, e)
        end
        return entities
	end;

	Functions = {
		Matter = function(_, entities)
		    for _, entity in entities.matter do
    			newWorld:despawn(entity)
    		end
        end;


		Jecs = function(_, entities)
		    for _, entity in entities.jecs do
				ecs:delete(entity)
			end
		end;
	};
}
