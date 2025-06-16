local types = require("../types")
local jecs = require(game:GetService("ReplicatedStorage").ecs)
local remotes = require("../remotes")
local collect = require("../collect")
local client_ids = {}


local function ecs_map_get(world, id)
	local deserialised_id = client_ids[id]

	if not deserialised_id then
		if world:has(id, jecs.Name) then
			deserialised_id = world:entity(id)
		else
			deserialised_id = world:entity()
		end

		client_ids[id] = deserialised_id
	end

	-- local deserialised_id = client_ids[id]
	-- if not deserialised_id then
	-- 	if world:has(id, jecs.Name) then
	-- 		deserialised_id = world:entity(id)
	-- 	else
	-- 		if world:exists(id) then
	-- 			deserialised_id = world:entity()
	-- 		else
	-- 			deserialised_id = world:entity(id)
	-- 		end
	-- 	end
	-- 	client_ids[id] = deserialised_id
	-- end

	return deserialised_id
end

local function ecs_make_alive_id(world, id)
	local rel = jecs.ECS_PAIR_FIRST(id)
	local tgt = jecs.ECS_PAIR_SECOND(id)

	rel = ecs_map_get(world, rel)
	tgt = ecs_map_get(world, tgt)

	return jecs.pair(rel, tgt)
end

local snapshots = collect(remotes.replication.OnClientEvent)

return function(world: types.World)
    for snapshot in snapshots do
        for id, map in snapshot do
        	id = tonumber(id)
            if jecs.IS_PAIR(id) then
            	id = ecs_make_alive_id(world, id)
            end

            local set = map.set
            if set then
                if jecs.is_tag(world, id) then
                   	for _, entity in set do
                       	entity = ecs_map_get(world, entity)
                  		world:add(entity, id)
                   	end
                else
	                local values = map.values
	                for i, entity in set do
						entity = ecs_map_get(world, entity)
                  		world:set(entity, id, values[i])
                   	end
			    end
            end

            local removed = map.removed

            if removed then
                for _, entity in removed do
                    entity = ecs_map_get(world, entity)
                    if not world:contains(entity) then
                        continue
                    end
                    world:remove(entity, id)
                end
            end
        end
    end
end
