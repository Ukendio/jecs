if not game then script = require "test/relative-string" end

local throw = require(script.Parent.throw)
local graph = require(script.Parent.graph)
type Node<T> = graph.Node<T>
type SourceNode<T> = graph.SourceNode<T>
local create_node = graph.create_node
local evaluate_node = graph.evaluate_node
local push_child_to_scope = graph.push_child_to_scope
local destroy = graph.destroy
local assert_stable_scope = graph.assert_stable_scope
local push_scope = graph.push_scope
local pop_scope = graph.pop_scope

type Map<K, V> = { [K]: V }

local function switch<T, U>(source: () -> T): (map: Map<T, ((() -> U)?)>) -> () -> U?
    local owner = assert_stable_scope()

    return function(map)
        local last_scope: Node<false>?
        local last_component: (() -> U)?

        local function update(cached): U?
            local component = map[source()]
            if component == last_component then return cached end
            last_component = component

            if last_scope then
                destroy(last_scope :: Node<any>)
                last_scope = nil
            end

            if component == nil then return nil end

            if type(component) ~= "function" then
                throw "map must map a value to a function"
            end

            local new_scope = create_node(owner, false, false)
            last_scope = new_scope :: Node<any>
            
            push_scope(new_scope)
        
            local ok, result = pcall(component)

            pop_scope()

            if not ok then error(result, 0) end

            return result
        end

        local node = create_node(owner, update, nil)

        evaluate_node(node)

        return function()
            push_child_to_scope(node)
            return node.cache
        end
    end
end

return switch
