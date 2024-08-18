local jecs = require(game:GetService("ReplicatedStorage").ecs)

-- I like the idea of only having the world be a singleton.
return jecs.World.new() :: jecs.World
