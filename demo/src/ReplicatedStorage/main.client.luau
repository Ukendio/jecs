local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.ecs)
local schedule = require(ReplicatedStorage.schedule)

local heartbeat = schedule(world,
	systems.entities_delete,
	systems.replication
)

game:GetService("RunService").Heartbeat:Connect(heartbeat)
