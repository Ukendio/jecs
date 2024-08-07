local reserved = 0

local function reserve()
    reserved += 1
    return reserved
end

-- If you don't like passing around a world singleton
-- and you need to register component IDs, just register them.
-- I dont use this because I like adding component traits
--[[
    local components = {
        Model = registry.reserve(),
        Transform = registry.reserve(),
    }

    local world = registry.register(jecs.World.new())
    local e = world:entity()
    world:set(e, components.Transform, CFrame)
]]
local function register(world)
    for _ = 1, reserved do
        world:component()
    end
    return world
end

return {
    reserve = reserve,
    register = register,
}
