local jecs = require("@jecs")
local ECS_GENERATION = jecs.ECS_GENERATION
local ECS_ID = jecs.ECS_ID
local __ = jecs.Wildcard
local pair = jecs.pair

local pe = require("@tools/entity_visualiser").prettify
local ansi = require("@tools/ansi")

function print_centered_entity(entity, width: number)
    local entity_str = tostring(entity)
    local entity_length = #entity_str

    local padding_total = width - 2 - entity_length

    local padding_left = math.floor(padding_total / 2)
    local padding_right = padding_total - padding_left

    local centered_str = string.rep(" ", padding_left) .. entity_str .. string.rep(" ", padding_right)

    print("|" .. centered_str .. "|")
end

local function name(world, e)
	return world:get(world, e, jecs.Name) or pe(e)
end

local function lifetime_tracker_add(world: jecs.World)
	local entity_index = world.entity_index
	local dense_array = entity_index.dense_array
	local component_index = world.component_index

	local ENTITY_RANGE = (jecs.Rest :: any) + 1

	local w = setmetatable({}, { __index = world })


	local world_entity = world.entity
	w.entity = function(self)
		local will_recycle = entity_index.max_id ~= entity_index.alive_count
		local e = world_entity(world)
		if will_recycle then
			print(`*recycled {pe(e)}`)
		else
			print(`*created {pe(e)}`)
		end
		return e
	end
	w.print_entity_index = function(self)
		local max_id = entity_index.max_id
		local alive_count = entity_index.alive_count
		local alive = table.move(dense_array, 1+jecs.Rest::any, alive_count, 1, {})
		local dead = table.move(dense_array, alive_count + 1, max_id, 1, {})

		local sep = "|--------|"
		if #alive > 0 then
			print("|-alive--|")
			for i = 1, #alive do
				local e = pe(alive[i])
				print_centered_entity(e, 32)
				print(sep)
			end
			print("\n")
		end

		if #dead > 0 then
			print("|--dead--|")
			for i = 1, #dead do
				print_centered_entity(pe(dead[i]), 32)
				print(sep)
			end
		end
	end
	local timelines = {}
	w.print_snapshot = function(self)
		local timeline = #timelines + 1
		local entity_column_width = 10
		local status_column_width = 8

		local header = string.format("| %-" .. entity_column_width .. "s |", "Entity")
		for i = 1, timeline do
			header = header .. string.format(" %-" .. status_column_width .. "s |", string.format("T%d", i))
		end

		local max_id = entity_index.max_id
		local alive_count = entity_index.alive_count
		local alive = table.move(dense_array, 1+jecs.Rest::any, alive_count, 1, {})
		local dead = table.move(dense_array, alive_count + 1, max_id, 1, {})

		local data = {}
		print("-------------------------------------------------------------------")
		print(header)

		-- Store the snapshot data for this timeline
		for i = ENTITY_RANGE, max_id do
			if dense_array[i] then
				local entity = dense_array[i]
				local id = ECS_ID(entity)
				local status = "alive"
				if id > alive_count then
					status = "dead"
				end
				data[id] = status
			end
		end

		table.insert(timelines, data)

		-- Create a table to hold entity data for sorting
		local entities = {}
		for i = ENTITY_RANGE, max_id do
			if dense_array[i] then
				local entity = dense_array[i]
				local id = ECS_ID(entity)
				-- Push entity and id into the new `entities` table
				table.insert(entities, {entity = entity, id = id})
			end
		end

		-- Sort the entities by ECS_ID
		table.sort(entities, function(a, b)
			return a.id < b.id
		end)

		-- Print the sorted rows
		for _, entity_data in ipairs(entities) do
			local entity = entity_data.entity
			local id = entity_data.id
			local status = "alive"
			if id > alive_count then
				status = "dead"
			end
			local row = string.format("| %-" .. entity_column_width .. "s     |", pe(entity))
			for j = 1, timeline do
				local timeline_data = timelines[j]
				local entity_data = timeline_data[id]
				if entity_data then
					row = row .. string.format(" %-" .. status_column_width .. "s |", entity_data)
				else
					row = row .. string.format(" %-" .. status_column_width .. "s |", "-")
				end
			end
			print(row)
		end
		print("-------------------------------------------------------------------")
	end
	local world_add = world.add
	local relations = {}
	w.add = function(self, entity: any, component: any)
		world_add(world, entity, component)
		if jecs.IS_PAIR(component) then
			local relation = jecs.pair_first(world, component)
			local target = jecs.pair_second(world, component)
			print(`*added ({pe(relation)}, {pe(target)}) to {pe(entity)}`)
			local rs = relations[relation]
			if not rs then
				local flags = component_index[component].flags
				rs = {
					fragmenting = bit32.band(flags, 0b0000_0010) ~= 0
				}
				relations[relation] = rs
			end
			local ts = rs[target]
			if not ts then
				ts = {}
				rs[target] = ts
			end
			table.insert(ts, entity)
		end

	end

	local world_delete = world.delete
	w.delete = function(self, e)
		local idr_t = component_index[pair(__, e)]
		if idr_t then
			for relation, ts in relations do
				local targets = ts[e]
				if not targets then
					continue
				end
				for _, target in targets do
					if type(target) == "boolean" then
						continue
					end
					if targets.fragmenting then
						print(`*deleted dependant {pe(target)}`)
					else
						local t = pe(target)
						print(`*removed dependency {ansi.red("(*, ")}{t}{ansi.green(")")} from {pe(e)}`)
					end
				end
			end
		end

		world_delete(world, e)
		print(`*deleted {pe(e)}`)
	end
	return w
end

return lifetime_tracker_add
