local ReplicatedStorage = game:GetService("ReplicatedStorage")
local blink = require(ReplicatedStorage.net)
local std = require(ReplicatedStorage.std)
local ref = std.ref
local world = std.world
local cts = std.components

local function syncMobs()
    for _, id, cf, vel in blink.SpawnMob.Iter() do
        local part = Instance.new("Part")
        part.Size = Vector3.one * 5
        part.BrickColor = BrickColor.Red()
        part.Anchored = true
        local model = Instance.new("Model")
        model.PrimaryPart = part
        part.Parent = model
        model.Parent = workspace

        ref("server-"..id)
            :set(cts.Transform, { new = cf, old = cf })
            :set(cts.Velocity, vel)
            :set(cts.Model, model)
            :add(cts.Mob)
    end
end

return function(scheduler: std.Scheduler)
    local phases = scheduler.phases
    local system_new = scheduler.systems.new
    system_new(syncMobs, phases.RenderStepped)
end
