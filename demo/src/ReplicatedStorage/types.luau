local jecs = require(game:GetService("ReplicatedStorage").ecs)
local observers_add = require("../ReplicatedStorage/observers_add")

export type World = typeof(observers_add(jecs.world()))
export type Entity = jecs.Entity
export type Id<T> = jecs.Id<T>

return {}
