if not game then script = require "test/relative-string" end
local typeof = game and typeof or require "test/mock".typeof :: never

local throw = require(script.Parent.throw)
local graph = require(script.Parent.graph)
local get_scope = graph.get_scope
local push_cleanup = graph.push_cleanup

local function helper(obj: any)
    return
        if typeof(obj) == "RBXScriptConnection" then function() obj:Disconnect() end
        elseif typeof(obj) == "Instance" then function() obj:Destroy() end
        elseif obj.destroy then function() obj:destroy() end
        elseif obj.disconnect then function() obj:disconnect() end
        elseif obj.Destroy then function() obj:Destroy() end
        elseif obj.Disconnect then function() obj:Disconnect() end
        else throw("cannot cleanup given object")
end

local function cleanup(value: unknown)
    local scope = get_scope()

    if not scope then
        throw "cannot cleanup outside a stable or reactive scope"
    end; assert(scope)

    if type(value) == "function" then
        push_cleanup(scope, value :: () -> ())
    else
        push_cleanup(scope, helper(value))
    end
end

type Destroyable = { destroy: (any) -> () } | { Destroy: (any) -> () }
type Disconnectable = { disconnect: (any) -> () } | { Disconnect: (any) -> () }

return cleanup ::
    ( (callback: () -> ()) -> () ) &
    ( (instance: Destroyable) -> () ) &
    ( (connection: Disconnectable) -> () ) &
    ( (instance: Instance) -> () ) &
    ( (connection: RBXScriptConnection) -> () )

