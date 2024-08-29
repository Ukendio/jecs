local ReplicatedStorage = game:GetService("ReplicatedStorage")
local std = require(ReplicatedStorage.std)
local scheduler = std.Scheduler
for _, module in script.Parent:WaitForChild("systems"):GetChildren() do
    require(module)(scheduler)
end
local events = scheduler.collect.all()

scheduler.systems.begin(events)
local jabby = require(ReplicatedStorage.Packages.jabby)
local client = jabby.obtain_client()
client.spawn_app(client.apps.home)
