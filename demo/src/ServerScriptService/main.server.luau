local ReplicatedStorage = game:GetService("ReplicatedStorage")
local std = require(ReplicatedStorage.std)
local loop = std.Scheduler(unpack(script.Parent.systems:GetChildren()))
game:GetService("RunService").Heartbeat:Connect(loop)
