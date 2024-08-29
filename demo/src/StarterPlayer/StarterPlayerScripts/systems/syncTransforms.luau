local ReplicatedStorage = game:GetService("ReplicatedStorage")
local blink = require(ReplicatedStorage.net)
local std = require(ReplicatedStorage.std)
local ref = std.ref
local world = std.world

local cts = std.components
local UpdateTransforms = ReplicatedStorage:WaitForChild("UpdateTransforms") :: RemoteEvent
local collect = std.collect
local stream = collect(UpdateTransforms.OnClientEvent)
local function syncTransforms()
    for _, id, cf in stream do
        local e = ref("server-"..id)
        local transform = e:get(cts.Transform)
        if not transform then
            continue
        end
        transform.new = cf
    end
end

return function(scheduler: std.Scheduler)
    return scheduler.systems.new(syncTransforms,
        scheduler.phases.RenderStepped)
end
