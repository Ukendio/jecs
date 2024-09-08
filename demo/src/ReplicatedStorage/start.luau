local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
        local client = jabby.obtain_client()
        local dtor
        UserInputService.InputBegan:Connect(function(input)
            if input.KeyCode == Enum.KeyCode.F4 then
                if dtor then
                    dtor()
                end
                dtor = client.spawn_app(client.apps.home)
 			end
        end)
	end
end

return start
