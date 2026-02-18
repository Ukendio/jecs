if not game then script = require "test/relative-string" end

local graph = require(script.Parent.graph)
type Node<T> = graph.Node<T>
local create_source_node = graph.create_source_node
local push_child_to_scope = graph.push_child_to_scope
local update_descendants = graph.update_descendants

export type Source<T> = (value: T?) -> T

local function source<T>(initial_value: T): Source<T>
    local node = create_source_node(initial_value)

    return function(...): T
        if select("#", ...) == 0 then -- no args were given
            push_child_to_scope(node)
            return node.cache
        end

        local v = ... :: T
        if node.cache == v and (type(v) ~= "table" or table.isfrozen(v)) then 
            return v
        end

        node.cache = v
        update_descendants(node)
        return v
    end
end

return source :: (<T>(initial_value: T) -> Source<T>) & (<T>() -> Source<T>)
