local ReplicatedStorage = game:GetService("ReplicatedStorage")
local std = require(ReplicatedStorage.std)
local scheduler = std.Scheduler
for _, module in script.Parent.systems:GetChildren() do
    require(module)(scheduler)
end
local events = scheduler.collect.all()
scheduler.systems.begin(events)
