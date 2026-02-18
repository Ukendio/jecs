if not game then script = require "test/relative-string" end

local graph = require(script.Parent.graph)
local create_node = graph.create_node
local push_child_to_scope = graph.push_child_to_scope
local assert_stable_scope = graph.assert_stable_scope
local evaluate_node = graph.evaluate_node

local function derive<T>(source: () -> T): () -> T
    local node = create_node(assert_stable_scope(), source, false :: any)

    evaluate_node(node)

    return function()
        push_child_to_scope(node)
        return node.cache
    end
end

return derive
