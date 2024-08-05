local ReplicatedStorage = game:GetService("ReplicatedStorage")

local jecs = require(ReplicatedStorage.ecs)
local pair = jecs.pair
local __ = jecs.Wildcard

local std = require(ReplicatedStorage.std)
local world = std.world

local cts = std.components

local Mob = cts.Mob
local Model = cts.Model
local Transform = cts.Transform
local Velocity = cts.Velocity
local Target = cts.Target
local Player = cts.Player
local Character = cts.Character

local function mobsMove(dt: number)
    local players = world:query(Character):with(Player)

    for mob, cf, v in world:query(Transform, Velocity)
        :with(Mob, Model)
    do
        local p = cf.Position

        local target
        for playerId, character in players do
            local pos = character.PrimaryPart.Position
            if true then
                target = pos
                break
            end
            if not target then
                target = pos
            elseif (p - pos).Magnitude < (p - target) then
                target = pos
            end
        end

        if not target then
            continue
        end

        local moving = CFrame.new(p + (target - p).Unit * dt * v)
        world:set(mob, Transform, moving)
    end
end

return mobsMove
