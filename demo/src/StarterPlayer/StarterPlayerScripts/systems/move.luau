local ReplicatedStorage = game:GetService("ReplicatedStorage")

local std = require(ReplicatedStorage.std)
local world = std.world

local cts = std.components

local Model = cts.Model
local Transform = cts.Transform

local function move(dt: number)
    for _, transform, model in world:query(Transform, Model):iter() do
        local cf = transform.new
        if cf ~= transform.old then
            local origo = model.PrimaryPart.CFrame
            model.PrimaryPart.CFrame = origo:Lerp(cf, 1)
            transform.old = cf
        end
    end
end

return function(scheduler: std.Scheduler)
    return scheduler.systems.new(move,
        scheduler.phases.RenderStepped)
end
