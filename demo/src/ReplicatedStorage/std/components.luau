local jecs = require(game:GetService("ReplicatedStorage").ecs)
local world = require(script.Parent.world)

local components = {
    Character = world:component(),
    Mob = world:component(),
    Model = world:component() :: jecs.Entity<Model>,
    Player = world:component(),
    Target = world:component(),
    Transform = world:component(),
    Velocity = world:component(),
}

return table.freeze(components)
