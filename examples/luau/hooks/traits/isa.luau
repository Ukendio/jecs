local jecs = require("@jecs")
local world = jecs.world()
local IsA = world:entity()
world:set(IsA, jecs.OnAdd, function(component, id)
	local second = jecs.pair_second(world, id)
	assert(second ~= component, "circular")

	local is_tag = jecs.is_tag(world, second)
	world:added(component, function(entity, _, value)
		if is_tag then
			world:add(entity, second)
		else
			world:set(entity, second, value)
		end
	end)

	world:removed(component, function(entity)
		world:remove(entity, second)
	end)

	if not is_tag then
		world:changed(component, function(entity, _, value)
			world:set(entity, second, value)
		end)
	end

	local r = jecs.record(world, second) :: jecs.Record
	local archetype = r.archetype
	if not archetype then
		return
	end
	local types = archetype.types

	for _, id in types do
		if jecs.is_tag(world, id) then
			world:add(component, id)
		else
			local metadata = world:get(second, id)
			if not world:has(component, id) then
				world:set(component, id, metadata)
			end
		end
	end

	-- jecs.bulk_insert(world, component, ids, values)
end)
