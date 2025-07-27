local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.ecs)
local schedule = require(ReplicatedStorage.schedule)

local SYSTEM = schedule.SYSTEM
local RUN = schedule.RUN
require(ReplicatedStorage.components)
local world = jecs.world()

local systems = ReplicatedStorage.systems
SYSTEM(world, systems.receive_replication)
SYSTEM(world, systems.entities_delete)
RUN(world)
