local jecs = require(game:GetService("ReplicatedStorage").ecs)
export type World = jecs.t_world

-- I like the idea of only having the world be a singleton.
return jecs.World.new()
