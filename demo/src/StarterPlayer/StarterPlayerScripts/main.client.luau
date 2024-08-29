local ReplicatedStorage = game:GetService("ReplicatedStorage")
local start = require(ReplicatedStorage.std.start)

start(script.Parent:WaitForChild("systems"):GetChildren())
