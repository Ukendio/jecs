local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jabby = require(ReplicatedStorage.Packages.jabby)
local Scheduler = require(ReplicatedStorage.std.scheduler)
local world = require(ReplicatedStorage.std.world)

local function start(modules)
    local scheduler = Scheduler.new(world)
    for _, module in modules do
        require(module)(scheduler)
    end
    local events = scheduler.collect.all()
    scheduler.systems.begin(events)
    if RunService:IsClient() then
        local client = jabby.obtain_client()
        local player = game:GetService("Players").LocalPlayer
        local apps = player:WaitForChild("PlayerGui")
        local dtor
        UserInputService.InputBegan:Connect(function(input)
            if input.KeyCode == Enum.KeyCode.F4 then
                if dtor then
                    dtor()
                end
                dtor = client.spawn_app(client.apps.home)
 			end
        end )
	end
end

return start
