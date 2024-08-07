local std = require(game:GetService("ReplicatedStorage").std)
local blink = require(game:GetService("ServerScriptService").net)

local ref = std.ref
local interval = std.interval
local cts = std.components

local Mob = cts.Mob
local Transform = cts.Transform
local Velocity = cts.Velocity

local throttle = interval(5)

local function spawnMobs()
    if throttle() then
        local p = Vector3.new(0, 5, 0)
        local cf = CFrame.new(p)
        local v = 5

        local id = ref()
            :set(Velocity, v)
            :set(Transform, cf)
            :add(Mob)
            .id()

        blink.SpawnMob.FireAll(id, cf, v)
    end
end

return spawnMobs
