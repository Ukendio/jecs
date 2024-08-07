local ReplicatedStorage = game:GetService("ReplicatedStorage")
local blink = require(ReplicatedStorage.net)
local std = require(ReplicatedStorage.std)
local ref = std.ref
local world = std.world

local cts = std.components

local function syncTransforms()
    for _, id, cf in blink.UpdateTransform.Iter() do
        ref("server-"..id)
            :set(cts.Transform, cf)
    end
end

return syncTransforms
