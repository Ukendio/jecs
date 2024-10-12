local jecs = require("@jecs")
local testkit = require("@testkit")

local world = jecs.World.new()

local A = world:component()
local B = world:component()

local e = world:entity()
world:add(e, A)
world:add(e, B)
local archetype_id = world.archetypeIndex["1_2"].id
world:delete(e)
testkit.print(world)
