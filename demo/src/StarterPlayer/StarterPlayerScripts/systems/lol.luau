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
local function system()
	for i, child in children do
		world:set(child, Position, vector.create(i,i,i))
	end
	for e, p in added:iter() do
		world:set(e, pre, p)
	end
	for i, child in children do
		if flip() then
			world:set(child, Position, vector.create(i + 1, i + 1, i + 1))
		end
	end
	for e, new, old in changed:iter() do
		if new ~= old then
			world:set(e, pre, new)
		end
	end

	for i, child in children do
		world:remove(child, Position)
	end

	for e in removed:iter() do
		world:remove(e, pre)
	end
end
local scheduler = require(std.scheduler)

scheduler.SYSTEM(system)

return 0
