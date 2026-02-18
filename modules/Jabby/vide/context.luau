if not game then script = require "test/relative-string" end

local throw = require(script.Parent.throw)
local graph = require(script.Parent.graph)
type Node<T> = graph.Node<T>
local create_node = graph.create_node
local get_scope = graph.get_scope
local push_scope = graph.push_scope
local pop_scope = graph.pop_scope
local set_context = graph.set_context

export type Context<T> = (() -> T) & (<U>(T, () -> U) -> U)

local nil_symbol = newproxy()
local count = 0

local function context<T>(...: T): Context<T>
    count += 1
    local id = count

    local has_default = select("#", ...) > 0
    local default_value = ...

    return function<T>(...): any -- todo: fix type error
        local scope: Node<unknown>? | false = get_scope()

        if select("#", ...) == 0 then -- get
            while scope do
                local ctx = scope.context
    
                if not ctx then
                    scope = scope.owner
                    continue
                end

                local value = (ctx :: { unknown })[id]

                if value == nil then
                    scope = scope.owner
                    continue
                end
                
                return (if value ~= nil_symbol then value else nil) :: T
            end

            if has_default ~= nil then
                return default_value
            else
                throw("attempt to get context when no context is set and no default context is set")
            end
        else -- set
            if not scope then return throw("attempt to set context outside of a vide scope") end

            local value, component = ...
            
            local new_scope = create_node(scope, false, false)
            set_context(new_scope, id, if value == nil then nil_symbol else value)

            push_scope(new_scope)

            local function efn(err: string) return debug.traceback(err, 3) end
            local ok, result = xpcall(component, efn)

            pop_scope()

            if not ok then
                throw(`error while running context:\n\n{result}`)
            end

            return result
        end

        return nil :: any
    end
end

return context
