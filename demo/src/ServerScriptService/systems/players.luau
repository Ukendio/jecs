local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local std = require(ReplicatedStorage.std)
local ref = std.ref
local collect = std.collect

local cts = std.components
local Player = cts.Player
local Character = cts.Character

local playersAdded = collect(Players.PlayerAdded)
local playersRemoved = collect(Players.PlayerRemoving)

local conn = {}

local function players()
    for _, player in playersAdded do
        std.world:set(
            std.world:entity(),
            std.world:entity())

        local e = ref(player.UserId):set(Player, player)
        local characterAdd = player.CharacterAdded
        conn[e.id()] = characterAdd:Connect(function(rig)
            while rig.Parent ~= workspace do
                task.wait()
            end
            e:set(Character, rig)
        end)
    end

    for _, player in playersRemoved do
        local id = ref(player.UserId):clear().id()
        conn[id]:Disconnect()
        conn[id] = nil
    end
end

return players
