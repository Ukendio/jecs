--!optimize 2
--!native
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local blink = require(game:GetService("ServerScriptService").net)
local jecs = require(ReplicatedStorage.ecs)
local __ = jecs.Wildcard

local std = require(ReplicatedStorage.std)
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

    for mob, cf, v in world:query(Transform, Velocity):with(Mob):iter() do
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
        world:set(mob, Transform, moving)
        blink.UpdateTransform.FireAll(mob, moving)
    end
end

return function(scheduler: std.Scheduler)
    return scheduler.systems.new(mobsMove,
        scheduler.phases.Heartbeat)
end
