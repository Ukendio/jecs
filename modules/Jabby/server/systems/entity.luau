local jecs = require(script.Parent.Parent.Parent.jecs)
local lon = require(script.Parent.Parent.Parent.modules.lon)
local queue = require(script.Parent.Parent.Parent.modules.queue)
local remotes = require(script.Parent.Parent.Parent.modules.remotes)
local reverse_connector = require(script.Parent.Parent.Parent.modules.reverse_connector)
local traffic_check = require(script.Parent.Parent.Parent.modules.traffic_check)
local types = require(script.Parent.Parent.Parent.modules.types)
local public = require(script.Parent.Parent.public)
local query_parser = require(script.Parent.Parent.query_parser)

local entity_index_try_get = jecs.entity_index_try_get
local IS_PAIR = jecs.IS_PAIR
local pair = jecs.pair
local pair_first = jecs.pair_first
local pair_second = jecs.pair_second
local empty_table = {}

local function get_all_components(world, entity): {}
	local record = entity_index_try_get(world.entity_index, entity)

	if not record then return empty_table end
	local archetype = record.archetype
	if not archetype then return empty_table end

	local components = {}
	for _, ty in archetype.types do 
		table.insert(components, ty)
	end
	return components
end

local function convert_component(world, debug, entity): string
 	if IS_PAIR(entity) then
		local left = convert_component(world, debug, pair_first(world, entity))
		local right = convert_component(world, debug, pair_second(world, entity))
		return `({left}, {right})`
	else
		return world:get(entity, debug) or `${tostring(entity)}`
	end
end

--- Indicates a value is a tag
local TAG = newproxy()
--- Indicates a value is set to nil; this is not allowed in 0.3.0
local BAD_VALUE = newproxy()

local function get_component(ctype_name: string, map_components: {[string]: number})

	local function get_entity(ctype: query_parser.PureComponent)
		local value = ctype.value

		if value.type == "Entity" then
			return value.entity
		elseif value.type == "Name" then
			return map_components[value.name]
		end
		error("bad")
	end

	local entity_to_set
	local parse = query_parser(ctype_name)[1]
	if parse.type == "Component" then
		entity_to_set = get_entity(parse)
	elseif parse.type == "Relationship" then
		local left, right = jecs.Wildcard, jecs.Wildcard

		if parse.left.type == "Component" then
			left = get_entity(parse.left)
		end

		if parse.right.type == "Component" then
			right = get_entity(parse.right)
		end

		entity_to_set = pair(left, right)
	end

	return entity_to_set
end

return function()

	local inspect_entity = queue(remotes.inspect_entity)
	local update_inspect_settings = queue(remotes.update_inspect_settings)
	local stop_inspect_entity = queue(remotes.stop_inspect_entity)
	local update_entity = queue(remotes.update_entity)
	local delete_entity = queue(remotes.delete_entity)

	local get_entity_component = queue(remotes.get_component)
	local validate_entity = queue(remotes.validate_entity_component)

	local inspectors = {}
	
	return function()

		for incoming, world_id, ctype_name in validate_entity:iter() do
			local world: types.World = public[world_id]
			local outgoing = reverse_connector(incoming)

			if not traffic_check.check_no_wl(incoming.host) then continue end
			if not world or world.class_name ~= "World" then continue end

			local map_components = {}
			for id, name in world.world:query(jecs.Name):iter() do
				map_components[name] = id
			end

			local ok, reason = pcall(get_component, ctype_name, map_components)

			remotes.validate_entity_component_result:fire(
				outgoing, world_id, ctype_name, ok, not ok and reason or nil
			)
		end

		for incoming, world_id, entity, inspect_id in inspect_entity:iter() do
			local world: types.World = public[world_id]
			local outgoing = reverse_connector(incoming)

			if not traffic_check.check_no_wl(incoming.host) then continue end
			if not world or world.class_name ~= "World" then continue end

			inspectors[inspect_id] = {
				outgoing = outgoing,
				world = world,
				entity = entity,
				paused = false,

				new_values = {},
				old_values = {}
			}
		end

		for incoming, inspect_id in stop_inspect_entity:iter() do
			if not traffic_check.check_no_wl(incoming.host) then continue end
			inspectors[inspect_id] = nil
		end

		for incoming, inspect_id in delete_entity:iter() do
			if not traffic_check.check_no_wl(incoming.host) then continue end
			local inspect_data = inspectors[inspect_id]
			local world_data = inspect_data.world
			local world = world_data.world
			local entity = inspect_data.entity

			world:delete(entity)
		end

		for incoming, inspect_id, settings in update_inspect_settings:iter() do
			if not traffic_check.check_no_wl(incoming.host) then continue end
			local inspect_data = inspectors[inspect_id]
			if not inspect_data then continue end
			inspect_data.paused = settings.paused
		end

		for incoming, inspect_id, component in get_entity_component:iter() do
			if not traffic_check.check_no_wl(incoming.host) then continue end
			local inspect_data = inspectors[inspect_id]
			local world_data = inspect_data.world
			local world = world_data.world
			local entity = inspect_data.entity
			local to = reverse_connector(incoming)

			local map_components = {}
			for id, name in world:query(jecs.Name):iter() do
				map_components[name] = id
			end

			local ok, component = pcall(get_component, component, map_components)
			
			if component and ok then
				remotes.return_component:fire(to, inspect_id, component, lon.output(world:get(entity, component), true, false))
			else
				remotes.return_component:fire(to, inspect_id, component, "nil")
			end
		end

		for incoming, inspect_id, changes in update_entity:iter() do
			if not traffic_check.check_no_wl(incoming.host) then continue end
			local inspect_data = inspectors[inspect_id]
			local world_data = inspect_data.world
			local world = world_data.world
			local entity = inspect_data.entity

			local map_components = {}
			for id, name in world:query(jecs.Name):iter() do
				map_components[name] = id
			end

			for ctype_name, value in changes do

				-- get the component we need to set
				local ok, entity_to_set = pcall(get_component, ctype_name, map_components)
				local old = world:get(entity, entity_to_set)

				if not ok then
					warn("attempted to set", ctype_name, "to", value)
					warn(entity_to_set)
					continue
				end

				local ok, result = pcall(lon.parse, value)

				if not ok then
					warn("attempted to set", ctype_name, "to", value)
					warn(result)
					continue
				end

				local ok, data = pcall(
					lon.compile,
					result,
					{ tag = TAG, old = old }
				)

				if not ok then
					warn("attempted to set", ctype_name, "to", value)
					warn(data)
					continue
				end

				if data == nil then
					world:remove(entity, entity_to_set)
				elseif data == TAG then
					-- trying to use world:set with a tag will result in an error,
					-- even if the data is nil, so instead we use world:add
					world:add(entity, entity_to_set)
				else
					world:set(entity, entity_to_set, data)
				end
			end
		end

		for inspect_id, inspector_data in inspectors do
			local world = inspector_data.world.world
			local entity = inspector_data.entity

			if inspector_data.paused then continue end
			if world:contains(entity) == false then continue end

			local new_values = inspector_data.new_values
			local old_values = inspector_data.old_values

			local components = get_all_components(world, entity)

			local function is_tag(id: jecs.Entity<any>)
				return jecs.is_tag(world, id)
			end

			for _, component in components do
				local name = convert_component(world, jecs.Name, component)
				local is_tag = is_tag(component)

				if is_tag then
					new_values[name] = TAG
				else
					local value = world:get(entity, component)
					new_values[name] = if value == nil then BAD_VALUE else value
				end
			end

			for name, new_value in new_values do
				local old_value = old_values[name]

				if old_value == new_value and typeof(new_value) ~= "table" then continue end
				remotes.inspect_entity_update:fire(
					inspector_data.outgoing,
					inspect_id,
					name,
					if new_value == TAG then "tag"
					--todo: figure out a better way to say that you are not allowed to store nil in a component
					elseif new_value == BAD_VALUE then "nil (not allowed)"
					else lon.output(new_value, true, true)
				)
			end

			for name, value in old_values do
				local new_value = new_values[name]

				if new_value ~= nil then continue end
				remotes.inspect_entity_update:fire(
					inspector_data.outgoing,
					inspect_id,
					name,
					nil
				)
			end
			
			table.clear(old_values)

			inspector_data.new_values = old_values
			inspector_data.old_values = new_values
		end
	end
end