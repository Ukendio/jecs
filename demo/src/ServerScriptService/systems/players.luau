local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local std = ReplicatedStorage.std
local ref = require(std.ref)
local collect = require(std.collect)

local cts = require(std.components)
local world = require(std.world)
local Player = cts.Player
local Character = cts.Character

local conn = {}

local function playersAdded(player: Player)
	local e = ref(player.UserId)
	world:set(e, Player, player)
	local characterAdd = player.CharacterAdded
	conn[e] = characterAdd:Connect(function(rig)
		while rig.Parent ~= workspace do
			task.wait()
		end
		world:set(e, Character, rig)
	end)
end

local function playersRemoved(player: Player) 
	local e = ref(player.UserId)
	world:clear(e)
	local connection = conn[e]
	connection:Disconnect()
	conn[e] = nil
end

local scheduler = require(std.scheduler)
local phases = require(std.phases)
scheduler.SYSTEM(playersAdded, phases.PlayerAdded)
scheduler.SYSTEM(playersRemoved, phases.PlayerRemoved)

return 0