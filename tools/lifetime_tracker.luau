local jecs = require("@jecs")
local ECS_GENERATION = jecs.ECS_GENERATION
local ECS_ID = jecs.ECS_ID
local __ = jecs.Wildcard
local pair = jecs.pair

local testkit = require("@testkit")
local BENCH, START = testkit.benchmark()

local it = testkit.test()
local TEST, CASE = it.TEST, it.CASE
local CHECK, FINISH = it.CHECK, it.FINISH
local SKIP, FOCUS = it.SKIP, it.FOCUS
local CHECK_EXPECT_ERR = it.CHECK_EXPECT_ERR


local c = {
	white_underline = function(s: any)
		return `\27[1;4m{s}\27[0m`
	end,

	white = function(s: any)
		return `\27[37;1m{s}\27[0m`
	end,

	green = function(s: any)
		return `\27[32;1m{s}\27[0m`
	end,

	red = function(s: any)
		return `\27[31;1m{s}\27[0m`
	end,

	yellow = function(s: any)
		return `\27[33;1m{s}\27[0m`
	end,

	red_highlight = function(s: any)
		return `\27[41;1;30m{s}\27[0m`
	end,

	green_highlight = function(s: any)
		return `\27[42;1;30m{s}\27[0m`
	end,

	gray = function(s: any)
		return `\27[30;1m{s}\27[0m`
	end,
}

local function pe(e: any)
	local gen = ECS_GENERATION(e)
	return c.green(`e{ECS_ID(e)}`)..c.yellow(`v{gen}`)
end

function print_centered_entity(entity, width: number)
    local entity_str = tostring(entity)
    local entity_length = #entity_str

    -- Calculate total padding needed to center the string
    local padding_total = width - 2 - entity_length  -- Subtract 2 for the `| |` characters

    -- Calculate padding for the left and right
    local padding_left = math.floor(padding_total / 2)
    local padding_right = padding_total - padding_left

    -- Build the centered string
    local centered_str = string.rep(" ", padding_left) .. entity_str .. string.rep(" ", padding_right)

    -- Print with pipes around the centered string
    print("|" .. centered_str .. "|")
end

local function lifetime_tracker_add(world: jecs.World)
	local entity_index = world.entity_index
	local dense_array = entity_index.dense_array
	local world_delete = world.delete
	local world_entity = world.entity
	local component_index = world.component_index

	local ENTITY_RANGE = (jecs.Rest :: any) + 1

	local w = setmetatable({}, { __index = world })
	w.delete = function(self, e)
		print("Entity deleted:", e)

		for child in world:each(pair(__, e)) do

		end
		return world_delete(world, e)
	end
	w.entity = function(self)
		local e = world_entity(world)
		print("Entity created:", pe(e))
		return e
	end
	w.print_entities = function(self)
		local max_id = entity_index.max_id
		local alive_count = entity_index.alive_count
		local alive = table.move(dense_array, 1+jecs.Rest::any, alive_count, 1, {})
		local dead = table.move(dense_array, alive_count + 1, max_id, 1, {})

		local sep = "|--------|"
		print("|-alive--|")
		for i = 1, #alive do
			local e = pe(alive[i])
			print_centered_entity(e, 32)
			print(sep)
		end
		print("\n")
		print("|--dead--|")
		for i = 1, #dead do
			print_centered_entity(pe(dead[i]), 32)
			print(sep)
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
	return w
end

return lifetime_tracker_add
