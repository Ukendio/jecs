local jecs = require("@jecs")

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

local world = jecs.World.new()
local Position = world:component()
local order = ""
hooks.OnSet(world, Position, function(entity, value)
    print("$1", entity, `({value.x}, {value.y}, {value.z})`)
    order ..= "$1"
end)
hooks.OnSet(world, Position, function(entity, value)
    print("$2", entity, `\{{value.x}, {value.y}, {value.z}}`)
    order ..= "-$2"
end)

world:set(world:entity(), Position, {x=1,y=0,z=1})

-- Output:
--  $1      270     (1, 0, 1)
--  $2      270     {1, 0, 1}

assert(order == "$1".."-".."$2")
