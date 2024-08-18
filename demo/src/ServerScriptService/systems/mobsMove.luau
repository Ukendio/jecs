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
    local players = world:query(Character):with(Player)

    for mob, cf, v in world:query(Transform, Velocity):with(Mob):iter() do
        local p = cf.Position

        local target

        for playerId, character in players:iter() do
            local pos = (character.PrimaryPart::Part).Position
            if true then
                target = pos
                break
            end
            if not target then
                target = pos
            elseif (p - pos).Magnitude
                < (p - target).Magnitude
            then
                target = pos
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

return mobsMove
