local ReplicatedStorage = game:GetService("ReplicatedStorage")
local std = require(ReplicatedStorage.std)

print(script.Parent:WaitForChild("systems"):GetChildren())
local loop = std.Scheduler(unpack(script.Parent:WaitForChild("systems"):GetChildren()))
game:GetService("RunService").Heartbeat:Connect(loop)
