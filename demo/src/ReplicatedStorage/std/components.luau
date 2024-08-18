local jecs = require(game:GetService("ReplicatedStorage").ecs)
local world = require(script.Parent.world)

type Entity<T=nil> = jecs.Entity<T>
local components: {
    Character: Entity<Model>,
    Mob: Entity,
    Model: Entity<Model>,
    Player: Entity,
    Target: Entity,
    Transform: Entity<CFrame>,
    Velocity: Entity<number>,
} = {
    Character = world:component(),
    Mob = world:component(),
    Model = world:component(),
    Player = world:component(),
    Target = world:component(),
    Transform = world:component(),
    Velocity = world:component(),
}

return table.freeze(components)
