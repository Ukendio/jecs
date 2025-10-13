local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local jecs = require(ReplicatedStorage.ecs)
local schedule = require(ReplicatedStorage.schedule)

local SYSTEM = schedule.SYSTEM
local RUN = schedule.RUN

require(ReplicatedStorage.components)
local world = jecs.world()

local systems = ServerScriptService.systems

local heartbeat = schedule(world,
	systems.players_added,
	systems.poison_hurts,
	systems.health_regen,
	systems.lifetimes_expire,
	systems.life_is_painful,
	systems.entities_delete,
	systems.replication
)

game:GetService("RunService").Heartbeat:Connect(heartbeat)
