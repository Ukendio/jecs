if not game then script = require "test/relative-string" end

local graph = require(script.Parent.graph)
local create_node = graph.create_node
local assert_stable_scope = graph.assert_stable_scope
local evaluate_node = graph.evaluate_node

local function effect<T>(callback: (T) -> T, initial_value: T)
    local node = create_node(assert_stable_scope(), callback, initial_value)

    evaluate_node(node)
end

return effect :: (<T>(callback: (T) -> T, initial_value: T) -> ()) & ((callback: () -> ()) -> ())
