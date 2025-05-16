local types = require("../types")
local jecs = require(game:GetService("ReplicatedStorage").ecs)
local remotes = require("../remotes")
local collect = require("../collect")
local client_ids = {}

local function ecs_map_get(world: types.World, id: types.Entity)
	local deserialised_id = client_ids[id]
	if not deserialised_id then
		if world:has(id, jecs.Name) then
			deserialised_id = world:entity(id)
		else
			if world:exists(id) then
				deserialised_id = world:entity()
			else
				deserialised_id = world:entity(id)
			end
		end
		client_ids[id] = deserialised_id
	end
	return deserialised_id
end

local function ecs_make_alive_id(world: types.World, id: jecs.Id)
	local rel = jecs.ECS_PAIR_FIRST(id)
	local tgt = jecs.ECS_PAIR_SECOND(id)

	ecs_map_get(world, rel)
	ecs_map_get(world, tgt)
end

local snapshots = collect(remotes.replication.OnClientEvent)

return function(world: types.World)
    return function()
        for snapshot in snapshots do
            for key, map in snapshot do
            	local id = (tonumber(key) :: any) :: jecs.Id
                if jecs.IS_PAIR(id) then
                	ecs_make_alive_id(world, id)
                end

                local set = map.set
                if set then
	                if jecs.is_tag(world, id) then
                       	for _, entity in set do
                        	entity = ecs_map_get(world, entity)
                      		world:add(entity, id)
                       	end
                    else
		                local values = map.values :: { any }
		                for i, entity in set do
							entity = ecs_map_get(world, entity)
                      		world:set(entity, id, values[i])
                       	end
				    end
                end

                local removed = map.removed
                if removed then
                    for i, e in removed do
                        if not world:contains(e) then
                            continue
                        end
                        world:remove(e, id)
                    end
                end
            end
        end
    end
end
