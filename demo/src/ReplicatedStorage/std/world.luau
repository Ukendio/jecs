local jecs = require(game:GetService("ReplicatedStorage").ecs)
export type World = jecs.WorldShim

return jecs.World.new()
