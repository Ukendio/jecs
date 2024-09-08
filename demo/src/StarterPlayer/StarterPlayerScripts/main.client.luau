local ReplicatedStorage = game:GetService("ReplicatedStorage")
local start = require(ReplicatedStorage.start)

start(script.Parent:WaitForChild("systems"):GetChildren())
