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

local connections = {}

local function players()
    for _, player in playersAdded do
        local e = ref(player.UserId):set(Player, player)

        connections[e.id()] = player.CharacterAdded:Connect(
            function(character)
                while character.Parent ~= workspace do
                    task.wait()
                end
                e:set(Character, character)
            end)
    end

    for _, player in playersRemoved do
        local id = ref(player.UserId):clear().id()
        connections[id]:Disconnect()
        connections[id] = nil
    end
end

return players
