--!optimize 2
--!native
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local blink = require(game:GetService("ServerScriptService").net)
local jecs = require(ReplicatedStorage.ecs)
local __ = jecs.Wildcard

local std = require(ReplicatedStorage.std)
local ref = std.ref
local interval = std.interval

local world: std.World = std.world
local cts = std.components

local Mob = cts.Mob
local Transform = cts.Transform
local Velocity = cts.Velocity
local Player = cts.Player
local Character = cts.Character

local function mobsMove(dt: number)
	local targets = {}
	for _, character in world:query(Character):with(Player):iter() do
		table.insert(targets, (character.PrimaryPart :: Part).Position)
	end

	for mob, transform, v in world:query(Transform, Velocity):with(Mob):iter() do
		local cf = transform.new
		local p = cf.Position

		local target
		local closest

		for _, pos in targets do
			local distance = (p - pos).Magnitude
			if not target or distance < closest then
				target = pos
				closest = distance
			end
		end

		if not target then
			continue
		end

		local moving = CFrame.new(p + (target - p).Unit * dt * v)
		transform.new = moving
		blink.UpdateTransform.FireAll(mob, moving)
	end
end

local throttle = interval(5)

local function spawnMobs()
	if throttle() then
		local p = Vector3.new(0, 5, 0)
		local cf = CFrame.new(p)
		local v = 5

		local id = ref():set(Velocity, v):set(Transform, { new = cf }):add(Mob).id()

		blink.SpawnMob.FireAll(id, cf, v)
	end
end

return function(scheduler: std.Scheduler)
	local phases = scheduler.phases
	local system_new = scheduler.systems.new
	system_new(mobsMove, phases.Heartbeat)
	system_new(spawnMobs, phases.Heartbeat)
end
