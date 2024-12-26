local std = game:GetService("ReplicatedStorage").std
local Players = game:GetService("Players")

local scheduler = require(std.scheduler)
local PHASE = scheduler.PHASE

return {
    PlayerAdded = PHASE({
        event = Players.PlayerAdded
    }),
    PlayerRemoved = PHASE({
        event = Players.PlayerRemoving
    })
}
