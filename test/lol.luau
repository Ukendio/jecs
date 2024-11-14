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


local ECS_PAIR_FLAG =                      0x8
local ECS_ID_FLAGS_MASK =                 0x10
local ECS_ENTITY_MASK =     bit32.lshift(1, 24)
local ECS_GENERATION_MASK = bit32.lshift(1, 16)

type i53 = number
type i24 = number

local function ECS_ENTITY_T_LO(e: i53): i24
	return if e > ECS_ENTITY_MASK then (e // ECS_ID_FLAGS_MASK) // ECS_ENTITY_MASK else e
end

local function ECS_GENERATION(e: i53): i24
	return if e > ECS_ENTITY_MASK then (e // ECS_ID_FLAGS_MASK) % ECS_GENERATION_MASK else 0
end

local ECS_ID = ECS_ENTITY_T_LO

local function ECS_COMBINE(source: number, target: number): i53
	return (source * 268435456) + (target * ECS_ID_FLAGS_MASK)
end

local function ECS_GENERATION_INC(e: i53)
	if e > ECS_ENTITY_MASK then
		local flags = e // ECS_ID_FLAGS_MASK
		local id = flags // ECS_ENTITY_MASK
		local generation = flags % ECS_GENERATION_MASK

		local next_gen = generation + 1
		if next_gen > ECS_GENERATION_MASK then
			return id
		end

		return ECS_COMBINE(id, next_gen) + flags
	end
	return ECS_COMBINE(e, 1)
end

local function bl()
	print("")
end

local function pe(e)
	local gen = ECS_GENERATION(e)
	return c.green(`e{ECS_ID(e)}`)..c.yellow(`v{gen}`)
end

local function dprint(tbl: {  [number]: number })
	bl()
	print("--------")
	for i, e in tbl do
		print("| "..pe(e).." |")
		print("--------")
	end
	bl()
end

local max_id = 0
local alive_count = 0
local dense = {}
local sparse = {}
local function alloc()
	if alive_count ~= #dense then
		alive_count += 1
		print("*recycled", pe(dense[alive_count]))
		return dense[alive_count]
	end
	max_id += 1
	local id = max_id
	alive_count += 1
	dense[alive_count] = id
	sparse[id] = {
		dense = alive_count
	}
	print("*allocated", pe(id))
	return id
end

local function remove(entity)
	local id = ECS_ID(entity)
	local r = sparse[id]
	local index_of_deleted_entity = r.dense
	local last_entity_alive_at_index = alive_count -- last entity alive
	alive_count -= 1
	local last_alive_entity = dense[last_entity_alive_at_index]
	local r_swap = sparse[ECS_ID(last_alive_entity)]
	r_swap.dense = r.dense
	r.dense = last_entity_alive_at_index
	dense[index_of_deleted_entity] = last_alive_entity
	dense[last_entity_alive_at_index] = ECS_GENERATION_INC(entity)
end

local function alive(e)
	local r = sparse[ECS_ID(e)]

	return dense[r.dense] == e
end

local function pa(e)
	print(`{pe(e)} is {if alive(e) then "alive" else "not alive"}`)
end

local tprint = require("@testkit").print
local e1v0 = alloc()
local e2v0 = alloc()
local e3v0 = alloc()
local e4v0 = alloc()
local e5v0 = alloc()
pa(e1v0)
pa(e4v0)
remove(e5v0)
pa(e5v0)

local e5v1 = alloc()
pa(e5v0)
pa(e5v1)
pa(e2v0)
print(ECS_ID(e2v0))

dprint(dense)
remove(e2v0)
dprint(dense)
