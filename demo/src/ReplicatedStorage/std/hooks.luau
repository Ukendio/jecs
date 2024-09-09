--!native
--!optimize 2
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.ecs)

local function create_cache(hook)
    local columns = setmetatable({}, {
        __index = function(self, component)
            local column = {}
            self[component] = column
            return column
        end
    })

    return function(world, component, fn)
        local column = columns[component]
        table.insert(column, fn)
        world:set(component, hook, function(entity, value)
            for _, callback in column do
                callback(entity, value)
            end
        end)
    end
end

local hooks = {
    OnSet = create_cache(jecs.OnSet),
    OnAdd = create_cache(jecs.OnAdd),
    OnRemove = create_cache(jecs.OnRemove)
}

return hooks
