local jecs = require(game:GetService("ReplicatedStorage").ecs)

local world = require(script.world) :: jecs.World
export type World = jecs.World

local scheduler = require(script.scheduler)
export type Scheduler = scheduler.Scheduler

local std = {
    ChangeTracker = require(script.changetracker),
    Scheduler = scheduler.new(world),
    bt = require(script.bt),
    collect = require(script.collect),
    components = require(script.components),
    ctx = require(script.ctx),
    handle = require(script.handle),
    interval = require(script.interval),
    ref = require(script.ref),
    world = world :: World,
    pair = jecs.pair,
    __ = jecs.w,
}

return std
