if not game then script = require "test/relative-string" end

local graph = require(script.Parent.graph)
type Node<T> = graph.Node<T>
local create_node = graph.create_node
local assert_stable_scope = graph.assert_stable_scope
local evaluate_node = graph.evaluate_node

function create_implicit_effect<T>(updater: (T) -> T, binding: T)
    evaluate_node(create_node(assert_stable_scope(), updater, binding))
end

type PropertyBinding = {
    instance: Instance,
    property: string,
    source: () -> unknown
}

local function update_property_effect(p: PropertyBinding)
    (p.instance :: any)[p.property] = p.source()
    return p
end

type ParentBinding = {
    instance: Instance,
    parent: () -> Instance
}

local function update_parent_effect(p: ParentBinding)
    p.instance.Parent = p.parent()
    return p
end

type ChildrenBinding = {
    instance: Instance,
    cur_children_set: { [Instance]: true },
    new_children_set: { [Instance]: true },
    children: () -> Instance | { Instance }
}

type ArrayOrV<V> = V | { V }
local function update_children_effect(p: ChildrenBinding)
    local cur_children_set: { [Instance]: true } = p.cur_children_set -- cache of all children parented before update
    local new_child_set: { [Instance]: true } = p.new_children_set -- cache of all children parented after update

    local new_children = p.children() -- all (and only) children that should be parented after this update
    
    if type(new_children) ~= "table" then
        new_children = { new_children }
    end

    local function process_child(child: ArrayOrV<Instance>)
        if type(child) == "table" then
            for _, child in next, child do
                process_child(child)
            end
        else
            if new_child_set[child] then return end -- stops redundant reparenting

            new_child_set[child] = true -- record child set from this update
            if not cur_children_set[child] then
                child.Parent = p.instance -- if child wasn't already parented then parent it
            else 
                cur_children_set[child] = nil -- remove child from cache if it was already in cache
            end
        end
    end

    process_child(new_children)

    for child in next, cur_children_set do
        child.Parent = nil -- unparent all children that weren't in the new children set
    end

    table.clear(cur_children_set) -- clear cache, preserve capacity
    p.cur_children_set, p.new_children_set = new_child_set, cur_children_set

    return p
end

return {
    property = function(instance, property, source)
        return create_implicit_effect(update_property_effect, {
            instance = instance,
            property = property,
            source = source
        })
    end,

    parent = function(instance, parent)
        return create_implicit_effect(update_parent_effect, {
            instance = instance,
            parent = parent
        })
    end,

    children = function(instance, children)
        return create_implicit_effect(update_children_effect, {
            instance = instance,
            cur_children_set = {},
            new_children_set = {},
            children = children
        })
    end
}
