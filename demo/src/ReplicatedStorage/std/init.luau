local jecs = require(game:GetService("ReplicatedStorage").ecs)

local world = require(script.world) :: jecs.World
export type World = jecs.World

local Scheduler = require(script.scheduler)
export type Scheduler = Scheduler.Scheduler

local std = {
    ChangeTracker = require(script.changetracker),
    Scheduler = Scheduler,
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
