local jecs = require("@jecs")

local function ecs_ensure_entity(world: jecs.World, id: jecs.Entity<any>, ctx: {[jecs.Entity<any>]: jecs.Entity<any>})
	local e = 0

	local ser_id = id

	local deser_id = ctx[ser_id]
	if not deser_id then
		if not world:exists(ser_id)
			or (world:contains(ser_id) and not world:get(ser_id, jecs.Name))
		then
			deser_id = world:entity(id)
		else
			if world:contains(ser_id)  then
				if world:has(ser_id, jecs.Name) then
					deser_id = ser_id
				else
					deser_id = world:entity(ser_id)
				end
			else
				if world:exists(ser_id) then
					deser_id = world:entity()
				else
					deser_id = world:entity(ser_id)
				end
			end
		end
		ctx[ser_id] = deser_id
	end

	e = deser_id

	return e
end

local function ecs_deser_pairs(world: jecs.World, rel, tgt, ctx)
	rel = ecs_ensure_entity(world, rel, ctx)
	tgt = ecs_ensure_entity(world, tgt, ctx)

	return jecs.pair(rel, tgt)
end

return {
	ecs_ensure_entity = ecs_ensure_entity,
	ecs_deser_pairs = ecs_deser_pairs,
}
