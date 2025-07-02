local types = require("../types")
local jecs = require(game:GetService("ReplicatedStorage").ecs)
local remotes = require("../remotes")
local collect = require("../collect")
local components = require("../components")


local client_ids: {[jecs.Entity]: jecs.Entity } = {}

local function ecs_ensure_entity(world: jecs.World, id: jecs.Entity)
	local e = 0

	local ser_id = id
	local deser_id = client_ids[ser_id]
	if deser_id  then
		if deser_id == 0 then
			local new_id = world:entity()
			client_ids[ser_id] = new_id
			deser_id = new_id
		end
	else
		if not world:exists(ser_id)
			or (world:contains(ser_id) and not world:get(ser_id, jecs.Name))
		then
			deser_id = world:entity()
		else
			if world:contains(ser_id) and world:get(ser_id, jecs.Name) then
				deser_id = ser_id
			else
				deser_id = world:entity()
			end
		end
		client_ids[ser_id] = deser_id
	end

	e = deser_id

	return e
end

-- local rel_render = `e{jecs.ECS_ID(rel)}v{jecs.ECS_GENERATION(rel)}`
-- local tgt_render = `e{jecs.ECS_ID(tgt)}v{jecs.ECS_GENERATION(tgt)}`
local function ecs_deser_pairs(world, token)
	local tokens = string.split(token, ",")
	local rel = tonumber(tokens[1])
	local tgt = tonumber(tokens[2])

	rel = ecs_ensure_entity(world, rel)
	tgt = ecs_ensure_entity(world, tgt)

	return jecs.pair(rel, tgt)
end

local snapshots = collect(remotes.replication.OnClientEvent)

return function(world: types.World)
	for entity in world:each(components.Destroy) do
		client_ids[entity] = nil
	end
    for snapshot in snapshots do
        for ser_id, map in snapshot do
        	local id = tonumber(ser_id)
            if not id then
            	id = ecs_deser_pairs(world, ser_id)
            else
            	id = ecs_ensure_entity(world, id)
            end

            local set = map.set
            if set then
                if jecs.is_tag(world, id) then
                   	for _, entity in set do
                       	entity = ecs_ensure_entity(world, entity)
                  		world:add(entity, id)
                   	end
                else
                	local t = os.clock()
	                local values = map.values
	                for i, entity in set do
						entity = ecs_ensure_entity(world, entity)
						world:set(entity, id, values[i])
                   	end
			    end
            end

            local removed = map.removed

            if removed then
                for _, entity in removed do
                    entity = ecs_ensure_entity(world, entity)
                    if not world:contains(entity) then
                        continue
                    end
                    world:remove(entity, id)
                end
            end
        end
    end
end
