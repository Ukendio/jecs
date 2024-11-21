local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local jabby = require(ReplicatedStorage.Packages.jabby)
local std = require(ReplicatedStorage.std)
local Scheduler = std.Scheduler
local world = std.world

local function start(modules)
	local scheduler = Scheduler.new(world, require(ReplicatedStorage.std.components))
	for _, module in modules do
		require(module)(scheduler)
	end
	local events = scheduler.collect.all()
	scheduler.systems.begin(events)

	jabby.set_check_function(function(player)
		return true
	end)
	if RunService:IsClient() then
		local player = game:GetService("Players").LocalPlayer
		local playergui = player:WaitForChild("PlayerGui")
		local client = jabby.obtain_client()
		UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.F4 then
				local home = playergui:FindFirstChild("Home")
				if home then
					home:Destroy()
				end
				client.spawn_app(client.apps.home)
			end
		end)
	end
end

return start
