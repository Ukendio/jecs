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
local world: std.World = std.world

local conn = {}

local function players()
	for _, player in playersAdded do
		world:set(std.world:entity(), cts.Transform)

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

return function(scheduler: std.Scheduler)
	local phases = scheduler.phases
	local system_new = scheduler.systems.new
	system_new(players, phases.Heartbeat)
end
