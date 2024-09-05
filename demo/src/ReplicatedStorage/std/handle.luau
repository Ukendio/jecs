local jecs = require(game:GetService("ReplicatedStorage").ecs)
local world = require(script.Parent.world)

type Handle = {
    has: (self: Handle, id: jecs.Entity) -> boolean,
    get: <T>(self: Handle, id: jecs.Entity<T>) -> T?,
    add: <T>(self: Handle, id: jecs.Entity<T>) -> Handle,
    set: <T>(self: Handle, id: jecs.Entity<T>, value: T) -> Handle,
    id: (self: Handle?) -> jecs.Entity
}

local handle: (e: jecs.Entity) -> Handle

do
    local e
    local function has(_, id)
        return world:has(e, id)
    end
    local function get(_, id)
        return world:get(e, id)
    end
    local function set(self, id, value)
        world:set(e, id, value)
        return self
    end
    local function add(self, id)
        world:add(e, id)
        return self
    end
    local function clear(self)
        world:clear(e)
        return self
    end
    local function delete(self)
        world:delete(e)
    end
    local function id()
        return e
    end

    local entity = {
        has = has,
        get = get,
        set = set,
        add = add,
        clear = clear,
        id = id,
    }

    function handle(id)
        e = id
        return entity
    end
end

return handle
