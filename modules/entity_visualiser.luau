local jecs = require("@jecs")
local ECS_GENERATION = jecs.ECS_GENERATION
local ECS_ID = jecs.ECS_ID

local ansi = {
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
	return ansi.green(`e{ECS_ID(e)}`) .. ansi.yellow(`v{gen}`)
end

local function name(world: jecs.World, id: any)
	return world:get(id, jecs.Name) or `${id}`
end

local function components(world: jecs.World, entity: any)
	local r = jecs.entity_index_try_get(world.entity_index, entity)
	if not r then
		return false
	end

	local archetype = r.archetype
	local row = r.row
	print(`Entity {pe(entity)}`)
	print("-----------------------------------------------------")
	for i, column in archetype.columns do
		local component = archetype.types[i]
		local n
		if jecs.IS_PAIR(component) then
			n = `({name(world, jecs.pair_first(world, component))}, {name(world, jecs.pair_second(world, component))})`
		else
			n = name(world, component)
		end
		local data = column[row] or "TAG"
		print(`| {n} | {data} |`)
	end
	print("-----------------------------------------------------")
	return true
end

local entity_index_try_get_any = jecs.entity_index_try_get_any

local function stringify(world: jecs.World)
	local function record(e: jecs.Entity): jecs.Record
		return entity_index_try_get_any(world.entity_index :: any, e :: any) :: any
	end
	local function tbl(e: jecs.Entity)
		return record(e).archetype
	end
	local function archetype(e: jecs.Entity)
		return tbl(e).type
	end
	local function records(e: jecs.Entity)
		return tbl(e).records
	end
	local function columns(e: jecs.Entity)
		return tbl(e).columns
	end
	local function row(e: jecs.Entity)
		return record(e).row
	end

	-- Important to order them in the order of their columns
	local function tuple(e, ...)
		for i, column in columns(e) do
			if select(i, ...) ~= column[row(e)] then
				return false
			end
		end
		return true
	end

	return {
		record = record,
		tbl = tbl,
		archetype = archetype,
		records = records,
		row = row,
		tuple = tuple,
		columns = columns
	}
end

return {
	components = components,
	prettify = pe,
	stringify = stringify
}
