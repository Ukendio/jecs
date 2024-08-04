local std = require(game:GetService("ReplicatedStorage").std)

local ref = std.ref
local interval = std.interval
local cts = std.components

local Mob = cts.Mob
local Model = cts.Model
local Transform = cts.Transform
local Velocity = cts.Velocity

local throttle = interval(5)

local function spawnMobs(world: std.World)
    if throttle() then
        local p = Vector3.new(0, 5, 0)
        local cf = CFrame.new(p)
        local v = 5
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.BrickColor = BrickColor.Blue()
        part.Size = Vector3.one * 5
        local model = Instance.new("Model")
        part.Parent = model
        model.PrimaryPart = part
        model.Parent = workspace

        ref()
            :set(Velocity, v)
            :set(Transform, cf)
            :set(Model, model)
            :add(Mob)
    end
end

return spawnMobs
