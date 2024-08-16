local jecs = require(game:GetService("ReplicatedStorage").ecs)
local world = require(script.world)

local std = {
    ChangeTracker = require(script.changetracker),
    Scheduler = require(script.scheduler),
    bt = require(script.bt),
    collect = require(script.collect),
    components = require(script.components),
    ctx = require(script.ctx),
    handle = require(script.handle),
    interval = require(script.interval),
    ref = require(script.ref),
    world = world,
    pair = jecs.pair,
    __ = jecs.w,
}

return std
