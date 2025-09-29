--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ct = require(ReplicatedStorage.components)
local components = ct :: { [string]: jecs.Entity }
local remotes = require(ReplicatedStorage.remotes)
local jecs = require(ReplicatedStorage.ecs)
local collect = require(ReplicatedStorage.collect)
local ty = require(ReplicatedStorage.types)

return function(world: jecs.World)
    local storages = {} :: { [jecs.Entity]: {[jecs.Entity]: any }}
    local networked_components = {}
    local networked_pairs = {}

	for component in world:each(ct.Networked) do
		local name = world:get(component, jecs.Name)
		assert(name)
		if components[name] == nil then
			error("Invalid component:"..name)
		end

        storages[component] = {}

        table.insert(networked_components, component)
    end

	for relation in world:each(ct.NetworkedPair) do
		local name = world:get(relation, jecs.Name)
		assert(name)
		if not components[name] then
			error("Invalid component")
		end
		table.insert(networked_pairs, relation)
	end

	for _, component in networked_components do
		local name = world:get(component, jecs.Name)
		if not name or not components[name] then
			-- error("Invalid component")
			error(`Networked Component (%id{component}%name{name})`)
		end
		local is_tag = jecs.is_tag(world, component)
		local storage = storages[component]
		if is_tag then
			world:added(component, function(entity)
				storage[entity] = true
			end)
		else
			world:added(component, function(entity, _, value)
				storage[entity] = value
			end)
			world:changed(component, function(entity, _, value)
				storage[entity] = value
			end)
		end

        world:removed(component, function(entity)
            storage[entity] = "jecs.Remove"
		end)
	end

	for _, relation in networked_pairs do
		world:added(relation, function(entity: jecs.Entity, id: jecs.Id, value)
			local is_tag = jecs.is_tag(world, id)
			local storage = storages[id]
			if not storage then
				storage = {}
				storages[id] = storage
			end
			if is_tag then
				storage[entity] = true
			else
				storage[entity] = value
			end
		end)

		world:changed(relation, function(entity: jecs.Id, id: jecs.Id, value)
			local is_tag = jecs.is_tag(world, id)
			if is_tag then
				return
			end

			local storage = storages[id]
			if not storage then
				storage = {}
				storages[id] = storage
			end

			storage[entity] = value
		end)

		world:removed(relation, function(entity, id)
			local storage = storages[id]
			if not storage then
				storage = {}
				storages[id] = storage
			end

			storage[entity] = "jecs.Remove"
		end)
	end

    -- local requested_snapshots = collect(remotes.request_snapshot.OnServerEvent)
    local players_added = collect(Players.PlayerAdded)

    return function(_, dt: number)
        local snapshot_lazy: ty.snapshot
        local set_ids_lazy: { jecs.Entity }

        -- In the future maybe it should be requested by the player instead when they
        -- are ready to receive the replication. Otherwise streaming could be complicated
        -- with intances references being nil.
		for player in players_added do
			if not snapshot_lazy then
				snapshot_lazy, set_ids_lazy =  {}, {}

				for component, storage in storages do
					local set_values = {}
					local set_n = 0

					local q = world:query(component)
					local is_tag = jecs.is_tag(world, component)
					for _, archetype in q:archetypes() do
						local entities = archetype.entities
						local entities_len = #entities
						table.move(entities, 1, entities_len, set_n + 1, set_ids_lazy)
						if not is_tag then
							local column = archetype.columns_map[component]
							table.move(column, 1, entities_len, set_n + 1, set_values)
						end

						set_n += entities_len
					end

					local set = table.move(set_ids_lazy, 1, set_n, 1, {})

					local map = {
	                    set = if set_n > 0 then set else nil,
	                    values = if set_n > 0 then set_values else nil,
	                }

					if jecs.IS_PAIR(component) then
						map.relation = jecs.pair_first(world, component)
						map.target = jecs.pair_second(world, component)
						map.pair = true
					end
				   	snapshot_lazy[tostring(component)] = map
				end
			end

			remotes.replication:FireClient(player, snapshot_lazy)
		end

		-- accumulator += dt

		-- Purposely sending less diffs of the world because doing it at 60hz
		-- gets expensive. But this requires interpolated elements in the scene.
		-- if accumulator > 1/60 then
		-- 	accumulator = 0

		local snapshot = {} :: ty.snapshot

		local set_ids = {}
		local removed_ids = {}

		for component, storage in storages do
		    local set_values = {} :: { any }
		    local set_n = 0
		    local removed_n = 0
		    for e, v in storage do
		        if v ~= "jecs.Remove" then
		            set_n += 1
		            set_ids[set_n] = e
		            set_values[set_n] = v or true
		        elseif world:contains(e) then
		            removed_n += 1
		            removed_ids[removed_n] = e
		        end
		    end

		    table.clear(storage)

            local dirty = false

            if set_n > 0 or removed_n > 0 then
            	dirty = true
            end

            if dirty then
            	local removed = table.move(removed_ids, 1, removed_n, 1, {}) :: { jecs.Entity }
             	local set = table.move(set_ids, 1, set_n, 1, {}) :: { jecs.Entity }

              	-- local ser_id: string = nil :: any

				-- if jecs.IS_PAIR(component) then
				-- 	ser_id = `{jecs.pair_first(world, component)},{jecs.pair_second(world, component)}`
				-- else
				-- 	ser_id = tostring(component)
				-- end

				local map = {
                    set = if set_n > 0 then set else nil,
                    values = if set_n > 0 then set_values else nil,
                    removed = if removed_n > 0 then removed else nil,
                }

				if jecs.IS_PAIR(component) then
					map.relation = jecs.pair_first(world, component)
					map.target = jecs.pair_second(world, component)
					map.pair = true
				end

				snapshot[tostring(component)] = map
	        end
        end
        if next(snapshot) ~= nil then
        	remotes.replication:FireAllClients(snapshot)
			-- print(snapshot)
        end
    end
end
