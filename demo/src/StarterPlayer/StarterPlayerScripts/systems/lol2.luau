--!optimize 2
--!native
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.ecs)
local __ = jecs.Wildcard
local std = ReplicatedStorage.std

local world = require(std.world)

local Position = world:component() :: jecs.Entity<vector>
local Previous = jecs.Rest
local pre = jecs.pair(Position, Previous)

local added = world
	:query(Position)
	:without(pre)
	:cached()
local changed = world
	:query(Position, pre)
	:cached()
local removed = world
	:query(pre)
	:without(Position)
	:cached()

local children = {}
for i = 1, 10 do
	local e = world:entity()
	world:set(e, Position, vector.create(i, i, i))
	table.insert(children, e)
end
local function flip()
	return math.random() > 0.5
end
local entity_index = world.entity_index
local function copy(archetypes, id)
	for _, archetype in archetypes do

		local to = jecs.archetype_traverse_add(world, pre, archetype)
		local columns = to.columns
		local records = to.records
		local old = columns[records[pre].column]
		local new =	columns[records[id].column]

		if to ~= archetype then
			for _, entity in archetype.entities do
				local r = jecs.entity_index_try_get_fast(entity_index, entity)
				jecs.entity_move(entity_index, entity, r, to)
			end
		end

		table.move(new, 1, #new, 1, old)

	end
end
local function system2()
	for i, child in children do
		world:set(child, Position, vector.create(i,i,i))
	end
	for e, p in added:iter() do
	end
	copy(added:archetypes(), Position)
	for i, child in children do
		if flip() then
			world:set(child, Position, vector.create(i + 1, i + 1, i + 1))
		end
	end

	for e, new, old in changed:iter() do
		if new ~= old then
		end
	end

	copy(changed:archetypes(), Position)

	for i, child in children do
		world:remove(child, Position)
	end

	for e in removed:iter() do
		world:remove(e, pre)
	end
end
local scheduler = require(std.scheduler)

scheduler.SYSTEM(system2)

return 0
