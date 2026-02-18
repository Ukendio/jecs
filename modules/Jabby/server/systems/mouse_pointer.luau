local jecs = require(script.Parent.Parent.Parent.jecs)
local queue = require(script.Parent.Parent.Parent.modules.queue)
local remotes = require(script.Parent.Parent.Parent.modules.remotes)
local reverse_connector = require(script.Parent.Parent.Parent.modules.reverse_connector)
local traffic_check = require(script.Parent.Parent.Parent.modules.traffic_check)
local types = require(script.Parent.Parent.Parent.modules.types)
local public = require(script.Parent.Parent.public)

local entity_index_try_get = jecs.entity_index_try_get
local IS_PAIR = jecs.IS_PAIR
local pair_first = jecs.pair_first
local pair_second = jecs.pair_second
local empty_table = {}


local function convert_component(world, debug, entity): string
	if IS_PAIR(entity) then
	   local left = convert_component(world, debug, pair_first(world, entity))
	   local right = convert_component(world, debug, pair_second(world, entity))
	   return `({left}, {right})`
   else
	   return world:get(entity, debug) or `${tostring(entity)}`
   end
end

local function get_type(t: { [any]: any }): string
	local key, value = next(t)
	if key == nil then return "" end
	return `[{typeof(key)}]: {typeof(value)}`
end

local function get_string_keys(t: { [any]: any }): ({ string }, boolean)
	local keys = {}
	local i = 0
	for key in t do
		if i > 3 then return keys, true end
		if typeof(key) ~= "string" then continue end
		table.insert(keys, key)
		i += 1
	end
	return keys, false
end

local function is_tag(world: jecs.World, id: jecs.Entity<any>)
	return jecs.is_tag(world, id)
end

local function get_all_components(world, entity): {}
	local record = entity_index_try_get(world.entity_index, entity)

	if not record then return empty_table end
	local archetype = record.archetype
	if not archetype then return empty_table end

	local components = {}
	for _, ty in archetype.types do 
		table.insert(components, ty)
	end

	table.sort(components, function(a, b)
		return if is_tag(world, a) and is_tag(world, b) then a < b
			elseif is_tag(world, a) then true
			elseif is_tag(world, b) then false
			else a < b
	end)

	return components
end

local function obtain_string(entity: jecs.Entity<any>, world: jecs.World)
	local MAX_SIZE = 840
	local has_more = false
	local entity_name = world:get(entity, jecs.Name)
	local strings = {`<b>{if entity_name then `{entity_name} #` else "#"}{entity}</b>\n`}
	local n = #strings[1]

	for _, id in get_all_components(world, entity) do
		if id == jecs.Name then continue end
		local name = convert_component(world, jecs.Name, id)
		local value = if is_tag(world, id) then nil else world:get(entity, id)
		local to_append

		if typeof(value) == "table" then
			local string_keys = get_string_keys(value)

			if #string_keys > 0 then
				local temp_b = {`<b>{name}</b>:`}
				local temp_n = #temp_b[1]

				for key, value in pairs(value) do
					if #temp_b > 0 then
						table.insert(temp_b, "\n")
					end

					local str_of_v = if type(value) == "string" then `{value}`
						elseif typeof(value) == "table" then get_type(value)
						else tostring(value)
					if #str_of_v > 32 then
						str_of_v = `{string.sub(str_of_v, 1, 30)}..`
					end

					local str = `{key}: {str_of_v}`

					if temp_n + #str + 2 > 32 then
						table.insert(temp_b, "...")
						break
					else
						table.insert(temp_b, str)
					end
				end

				to_append = `{table.concat(temp_b)}`
			else
				to_append = `<b>{name}</b>: {get_type(value)}`
			end
		elseif is_tag(world, id) then
			to_append = `<b>{name}</b>`
		else
			local value = tostring(value)
			if #value > 32 then
				to_append = `<b>{name}</b>: {string.sub(value, 1, 30)}..`
			else
				to_append = `<b>{name}</b>: {value}`
			end
		end
		
		if MAX_SIZE > n + #to_append then
			n += #to_append
			table.insert(strings, to_append)
		else
			has_more = true
		end
	end

	local str = table.concat(strings, "\n")
	if has_more then str = str .. "..." end

	return str
end

return function()

	local send_mouse_pointer = queue(remotes.send_mouse_pointer)

	return function()

		for incoming, world_id, pos, dir in send_mouse_pointer:iter() do
			if not traffic_check.check_no_wl(incoming.host) then continue end
			local world_data: types.World = public[world_id]
			local world = world_data.world
			local outgoing = reverse_connector(incoming)

			if world_data.entities == nil and world_data.get_entity_from_part == nil then continue end
			if not world_data or world_data.class_name ~= "World" then continue end

			local result = workspace:Raycast(pos, dir * 1000)
			
			if not result then
				remotes.send_mouse_entity:fire(
					outgoing,
					world_id
				)
				continue
			end

			local part = result.Instance
			local entity

			-- no way to obtain the entity
			if world_data.get_entity_from_part == nil and world_data.entities == nil then
				remotes.send_mouse_entity:fire(
					outgoing,
					world_id
				)
				continue
			end

			if world_data.get_entity_from_part == nil then
				entity = world_data.entities[part]

				while entity == nil and part.Parent ~= game do
					part, entity = part.Parent, world_data.entities[part]
				end
			else
				entity, part = world_data.get_entity_from_part(part)
			end

			if not entity then 
				remotes.send_mouse_entity:fire(
					outgoing,
					world_id
				)
				continue
			end

			local str = obtain_string(entity, world, jecs.Name)

			remotes.send_mouse_entity:fire(
				outgoing,
				world_id,
				part,
				entity,
				str
			)

		end

	end
end
