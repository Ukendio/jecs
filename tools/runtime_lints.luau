local function dbg_info(n: number): any
	return debug.info(n, "s")
end
local function throw(msg: string)
	local s = 1
	local root = dbg_info(1)
	repeat
		s += 1
	until dbg_info(s) ~= root
	if warn then
		error(msg, s)
	else
		print(`[jecs] error: {msg}\n`)
	end
end

local function ASSERT<T>(v: T, msg: string)
	if v then
		return
	end
	throw(msg)
end

local function runtime_lints_add(world)
	local function get_name(id)
		return world_get_one_inline(world, id, EcsName)
	end

	local function bname(id): string
		local name: string
		if ECS_IS_PAIR(id) then
			local first = get_name(world, ecs_pair_first(world, id))
			local second = get_name(world, ecs_pair_second(world, id))
			name = `pair({first}, {second})`
		else
			return get_name(world, id)
		end
		if name then
			return name
		else
			return `${id}`
		end
	end

	local function ID_IS_TAG(world: World, id)
		if ECS_IS_PAIR(id) then
			id = ecs_pair_first(world, id)
		end
		return not world_has_one_inline(world, id, EcsComponent)
	end

	World.query = function(world: World, ...)
		ASSERT((...), "Requires at least a single component")
		return world_query(world, ...)
	end

	World.set = function(world: World, entity: i53, id: i53, value: any): ()
		local is_tag = ID_IS_TAG(world, id)
		if is_tag and value == nil then
			local _1 = bname(world, entity)
			local _2 = bname(world, id)
			local why = "cannot set component value to nil"
			throw(why)
			return
		elseif value ~= nil and is_tag then
			local _1 = bname(world, entity)
			local _2 = bname(world, id)
			local why = `cannot set a component value because {_2} is a tag`
			why ..= `\n[jecs] note: consider using "world:add({_1}, {_2})" instead`
			throw(why)
			return
		end

		world_set(world, entity, id, value)
	end

	World.add = function(world: World, entity: i53, id: i53, value: any)
		if value ~= nil then
			local _1 = bname(world, entity)
			local _2 = bname(world, id)
			throw("You provided a value when none was expected. " .. `Did you mean to use "world:add({_1}, {_2})"`)
		end

		world_add(world, entity, id)
	end

	World.get = function(world: World, entity: i53, ...)
		local length = select("#", ...)
		ASSERT(length < 5, "world:get does not support more than 4 components")
		local _1
		for i = 1, length do
			local id = select(i, ...)
			local id_is_tag = not world_has(world, id, EcsComponent)
			if id_is_tag then
				local name = get_name(world, id)
				if not _1 then
					_1 = get_name(world, entity)
				end
				throw(
					`cannot get (#{i}) component {name} value because it is a tag.`
						.. `\n[jecs] note: If this was intentional, use "world:has({_1}, {name}) instead"`
				)
			end
		end

		return world_get(world, entity, ...)
	end
end
