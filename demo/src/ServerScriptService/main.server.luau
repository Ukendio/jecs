local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local jecs = require(ReplicatedStorage.ecs)
local schedule = require(ReplicatedStorage.schedule)
local observers_add = require(ReplicatedStorage.observers_add)

local SYSTEM = schedule.SYSTEM
local RUN = schedule.RUN

require(ReplicatedStorage.components)
local world = observers_add(jecs.world())

local systems = ServerScriptService.systems

SYSTEM(world, systems.replication)
SYSTEM(world, systems.players_added)
SYSTEM(world, systems.poison_hurts)
SYSTEM(world, systems.life_is_painful)
RUN(world, 0)
