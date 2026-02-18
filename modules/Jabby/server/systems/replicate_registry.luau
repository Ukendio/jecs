local jecs = require(script.Parent.Parent.Parent.jecs)
local queue = require(script.Parent.Parent.Parent.modules.queue)
local remotes = require(script.Parent.Parent.Parent.modules.remotes)
local reverse_connector = require(script.Parent.Parent.Parent.modules.reverse_connector)
local traffic_check = require(script.Parent.Parent.Parent.modules.traffic_check)
local types = require(script.Parent.Parent.Parent.modules.types)
local public = require(script.Parent.Parent.public)
local query_parser = require(script.Parent.Parent.query_parser)

type Connection = {

	outgoing: types.OutgoingConnector,
	query_id: number,
	frame: number,

	paused: boolean,
	refresh: boolean,

	world: types.World,

	include: {jecs.Entity<any>},
	exclude: {jecs.Entity<any>},
	with: {jecs.Entity<any>},

	new_columns: {{any}},
	old_columns: {{any}},	
	
	from: number,
	upto: number

}

local NIL = newproxy() -- NULL is displayed if the value exists, buth as no value

local function clear_columns(columns: {{any}})
	for _, column in columns do
		local name = column[1]
		table.clear(column)
		column[1] = name
		assert(column[1] == name)
	end
	return columns
end

local function reverse_columns(columns: {{any}}, size: number)
	for _, column in columns do
		for i = 0, size // 2 - 1 do
			column[i + 2], column[(size + 1) - i] = column[(size + 1) - i], column[i + 2]
		end
	end
	return columns
end

return function()

	local processing_queries: {[number]: Connection} = {}

	local validate_query = queue(remotes.validate_query)
	local request_query = queue(remotes.request_query)
	local disconnect_query = queue(remotes.disconnect_query)
	local advance_query_page = queue(remotes.advance_query_page)
	local pause_query = queue(remotes.pause_query)
	local refresh_query = queue(remotes.refresh_results)

	local function check_if_query_valid(world: types.World, query: string): (boolean, string)
		local map_components = {}
		local ok, result = pcall(query_parser, query)
		local msg = nil

		if not ok then
			return ok, result :: any
		end

		for id, name in world.world:query(jecs.Name):iter() do
			map_components[name] = id
		end

		local total_to_query = 0

		for _, ctype in result do
			if not ok then break end

			if ctype.query and not ctype.exclude then
				total_to_query += 1
			end

			if ctype.type == "Component" then
				if ctype.value.type == "Entity" then
					if world.world:contains(ctype.value.entity) then continue end
					return false, "entity does not exist"
				elseif ctype.value.type == "Name" then
					if map_components[ctype.value.name] then continue end
					return false, `unknown component called {ctype.value.name}`
				else
					return false, "what"
				end
			elseif ctype.type == "Relationship" then
				local both_wildcard = ctype.left.type == "Wildcard" and ctype.right.type == "Wildcard"
				if both_wildcard then
					return false, `(*, *) is not a valid relationship`
				end

				local left = ctype.left
				local right = ctype.right

				if left.type == "Component" then
					if left.value.type == "Entity" then
						if world.world:contains(left.value.entity) then continue end
						return false, "entity does not exist"
					elseif left.value.type == "Name" then
						if map_components[left.value.name] then continue end
						return false, `unknown component called {left.value.name}`
					else
						return false, "what"
					end
				end

				if right.type == "Component" then
					if right.value.type == "Entity" then
						if world.world:contains(right.value.entity) then continue end
						return false, "entity does not exist"
					elseif right.value.type == "Name" then
						if map_components[right.value.name] then continue end
						return false, `unknown component called {right.value.name}`
					else
						return false, "what"
					end
				end
			end
		end

		if total_to_query > 26 then
			warn("attempting to observe too many values")
			return false, "attempting to observe too many entities"
		end

		return ok, msg
	end

	--fixme: contains is missing from types
	local function check_if_still_valid(world: any, entities: {any})
		for _, id in entities do
			if jecs.IS_PAIR(id) then
				if not (world:contains(jecs.pair_first(world, id) and jecs.pair_second(world, id))) then
					return false
				end
			elseif not world:contains(id) then
				return false
			end
		end
		return true
	end

	local function get_terms(query: string, world: jecs.World)
		local result = query_parser(query)
		local include = {}
		local exclude = {}
		local with = {}

		local map_components = {}
		local map_entity: {[any]: any} = {}
		for id, name in world:query(jecs.Name):iter() do
			map_components[name] = id
		end

		local function get_entity(ctype: query_parser.PureComponent)
			local value = ctype.value

			if value.type == "Entity" then
				return value.entity
			elseif value.type == "Name" then
				return map_components[value.name]
			end
			error("bad")
		end

		for _, ctype in result do
			if ctype.type == "Component" then
				map_entity[ctype] = get_entity(ctype)
			elseif ctype.type == "Relationship" then
				local left, right = jecs.Wildcard, jecs.Wildcard

				if ctype.left.type == "Component" then
					left = get_entity(ctype.left)
				end

				if ctype.right.type == "Component" then
					right = get_entity(ctype.right)
				end

				local pair = jecs.pair(left, right)
				map_entity[ctype] = pair
			end
		end

		for _, ctype in result do
			local entity = map_entity[ctype]
			if ctype.exclude then
				table.insert(exclude, entity)
			elseif ctype.query then
				-- local name = if ctype.type == "Component" then ctype.name else `({ctype.left.name}, {ctype.right.name})`
				table.insert(include, entity)
			else
				table.insert(with, entity)
			end
		end

		return include, exclude, with
	end

	return function()

		for incoming, world_id, query in validate_query:iter() do
			if not traffic_check.check_no_wl(incoming.host) then continue end

			local world: types.World = public[world_id]
			local outgoing = reverse_connector(incoming)

			if not world or world.class_name ~= "World" then
				remotes.validate_result:fire(outgoing, world_id, query, nil, false, "world does not exist")
				continue
			end

			local ok, message = check_if_query_valid(world, query)
			local include, exclude, with

			if ok then include, exclude, with = get_terms(query, world.world) end

			remotes.validate_result:fire(outgoing, world_id, query, ok and {
				include = include,
				exclude = exclude,
				with = with
			}, ok, message)
		end

		for incoming, query_id in disconnect_query:iter() do
			processing_queries[query_id] = nil
		end
		
		for incoming, world_id, query_id, query in request_query:iter() do
			if not traffic_check.check_no_wl(incoming.host) then continue end

			local world: types.World = public[world_id]
			local outgoing = reverse_connector(incoming)

			if not world or world.class_name ~= "World" then continue end

			local ok = check_if_query_valid(world, query)
			
			if not ok then continue end

			local include, exclude, with = get_terms(query, world.world)
			local new_columns = {}
			local old_columns = {}

			table.insert(new_columns, {})
			table.insert(old_columns, {})

			for _, ctype in include do
				table.insert(new_columns, {})
				table.insert(old_columns, {})
			end

			if processing_queries[query_id] then
				local connection = processing_queries[query_id]

				connection.outgoing = outgoing
				connection.query_id = query_id
				connection.world = world
				connection.refresh = true

				connection.include = include
				connection.exclude = exclude
				connection.with = with

				connection.new_columns = new_columns
				connection.old_columns = old_columns
				connection.from = 1
				connection.upto = 25
			else
				local connection: Connection = {

					outgoing = outgoing,
					query_id = query_id,
					frame = 0,
	
					world = world,

					paused = false,
					refresh = false,
	
					include = include,
					exclude = exclude,
					with = with,
	
					new_columns = new_columns,
					old_columns = old_columns,
	
					from = 1,
					upto = 25
				}
	
				processing_queries[query_id] = connection
			end
		end

		for incoming, query_id in refresh_query:iter() do
			if not traffic_check.check_no_wl(incoming.host) then continue end
			local query = processing_queries[query_id]
			if not query then continue end
			query.refresh = true
		end

		for incoming, query_id, state in pause_query:iter() do
			if not traffic_check.check_no_wl(incoming.host) then continue end
			local query = processing_queries[query_id]
			if not query then continue end
			query.paused = state
		end

		for incoming, query_id, from, to in advance_query_page:iter() do
			if not traffic_check.check_no_wl(incoming.host) then continue end
			local query = processing_queries[query_id]
			if not query then continue end

			query.refresh = true
			query.from = from
			query.upto = to
		end

		for query_id, query_data in processing_queries do
			if query_data.paused and query_data.refresh ~= true then continue end
			debug.profilebegin("process query")
			query_data.refresh = false
			local world_data = query_data.world
			local world = world_data.world
			local debug_trait = jecs.Name

			if
				not (check_if_still_valid(world, query_data.include)
				and check_if_still_valid(world, query_data.exclude)
				and check_if_still_valid(world, query_data.with))
			then
				-- query is no longer valid!
				--todo: query is invalid, notify the client about this
				debug.profileend()
				continue
			end

			local query = world:query(unpack(query_data.include))

			if #query_data.exclude > 0 then
				query = query:without(unpack(query_data.exclude))
			end

			if #query_data.with > 0 then
				query = query:with(unpack(query_data.with))
			end

			local from = query_data.from
			local upto = query_data.upto
			
			local new_columns = query_data.new_columns
			local old_columns = query_data.old_columns
			-- set the names of each column
			--todo: fix type
			local function get_name(entity: any)
				if jecs.IS_PAIR(entity) then
					local left = jecs.pair_first(world, entity)
					local right = jecs.pair_second(world, entity)
					return `({get_name(left)}, {get_name(right)})`
				elseif entity == jecs.Wildcard :: any then
					return "*"
				elseif world:has(entity, debug_trait) then
					return world:get(entity, debug_trait)
				else
					return `${entity}`
				end
			end

			-- set column names
			for index, column in new_columns do
				local e = query_data.include[index - 1]

				if e then
					column[1] = get_name(e)
				else
					column[1] = "id"
				end
			end

			-- process the data into columns
			-- we inline the query here, as jecs queries are in reverse to prevent iterator invalidation
			-- this is usually fine, but it's annoying, as now entities are added to the first page.
			--todo: pause button
			local total_entities = 0
			local archetypes = query:archetypes()

			for _, archetype: jecs.Archetype in archetypes do
				total_entities += #archetype.entities
			end

			local entities = table.create(total_entities)
			local at = total_entities
			local row_entity = 1

			for _, archetype: jecs.Archetype in archetypes do
				for row = #archetype.entities, 1, -1 do
					local entity = archetype.entities[row]
					table.insert(entities, entity)
				end
			end

			table.sort(entities)

			for i = from, upto do
				row_entity += 1
				local entity = entities[i]
				if not entity then continue end
				new_columns[1][row_entity] = entity
				for idx, ctype in query_data.include do
					local value = world:get(entity, ctype)
					new_columns[idx + 1][row_entity] = if value == nil then NIL else value
				end
			end

			--- reverse the order of each array

			remotes.count_total_entities:fire(
				query_data.outgoing,
				query_id,
				total_entities
			)

			-- diff the columns and replicate any new values
			for column = 1, math.max(#new_columns, #old_columns) do
				for row = 1, upto do
					local new_value = new_columns[column][row]
					local old_value = old_columns[column][row]

					if new_value ~= old_value or typeof(new_value) == "table" then
						-- todo: improve replication of the new value
						-- ideally, we would figure out if the value is a certain type and needs special replication
						-- if we for example determine a value is a string, or table, we cap it at MAX_CHARACTERS
						-- or we tostring a couple keys of the table until we reach MAX_CHARACTERS.
						-- we wanna be able to replicate every single. value

						local MAX_CHARS = 750
						local str

						if typeof(new_value) == "string" then
							str = `"{string.sub(new_value, 1, MAX_CHARS-2)}"`
						elseif typeof(new_value) == "table" then
							local temp_n = 0
							local temp_b = {}

							for key, value in new_value do
								if #temp_b > 0 then
									table.insert(temp_b, "; ")
								end
								
								local str_of_v = if type(value) == "string" then `"{value}"` else tostring(value)
								local str = `{key}: {str_of_v}`

								if temp_n + #str + 2 > MAX_CHARS then
									table.insert(temp_b, "...")
									break
								else
									table.insert(temp_b, str)
								end
							end

							str = `\{{table.concat(temp_b)}\}`
						elseif new_value == NIL then
							str = "" -- important distinction, this is still a valid component
						elseif new_value == nil then
							str = nil -- but this isnt
						else
							str = string.sub(tostring(new_value), 1, MAX_CHARS-2)
						end

						if row == 1 then str = new_value end
						remotes.update_query_result:fire(
							query_data.outgoing,
							query_id,
							query_data.frame,
							column,
							row,
							str
						)
					end
				end
			end

			query_data.new_columns = clear_columns(old_columns)
			query_data.old_columns = new_columns
			query_data.frame += 1
			debug.profileend()
		end

	end

end