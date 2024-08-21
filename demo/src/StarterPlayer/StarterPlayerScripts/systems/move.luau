local ReplicatedStorage = game:GetService("ReplicatedStorage")

local std = require(ReplicatedStorage.std)
local world = std.world

local cts = std.components

local Model = cts.Model
local Transform = cts.Transform

local function move(dt: number)
    for _, cf, model in world:query(Transform, Model) do
        model.PrimaryPart.CFrame = cf
    end
end

return function(scheduler: std.Scheduler)
    return scheduler.systems.new(move,
        scheduler.phases.RenderStepped)
end
