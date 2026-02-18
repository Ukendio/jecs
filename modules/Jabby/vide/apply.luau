if not game then script = require "test/relative-string" end
local typeof = game and typeof or require "test/mock".typeof :: never
local Vector2 = game and Vector2 or require "test/mock".Vector2 :: never
local UDim2 = game and UDim2 or require "test/mock".UDim2 :: never

local flags = require(script.Parent.flags)
local throw = require(script.Parent.throw)
local bind = require(script.Parent.bind)
local _, is_action = require(script.Parent.action)()
local graph = require(script.Parent.graph)
type Node<T> = graph.Node<T>

type Array<V> = { V }
type ArrayOrV<V> = {ArrayOrV<V>} | V
type Map<K, V> = { [K]: V }

local free_caches: {
    -- event listeners to connect after properties are set
    events: Map<
        string, -- event name
        () -> () -- listener
    >,

    -- actions to run after events are connected
    actions: Map<
        number, -- priority
        Array<(Instance) -> ()> -- action callbacks
    >,

    -- cache to detect duplicate property setting at same nesting depth
    nested_debug: Map<
        number, -- depth
        Map<string, true> -- set of property names
    >,

    -- use stack instead of recursive function to process nesting layers one at time
    -- deeper-nested properties take precedence over shallower-nested ones
    -- each nested layer occupies two indexes: 1. table ref 2. nested depth
    -- e.g. { t1 = { t3 = {} }, t2 = {} } -> { t1, 1, t2, 1, t3, 2 }
    nested_stack: { {} | number }
}?

local function borrow_caches(): typeof(assert(free_caches))
    if free_caches then
        local caches = free_caches :: typeof(assert(free_caches))
        free_caches = nil
        return caches
    else
        return {
            events = {},
            actions = setmetatable({} :: any, { -- lazy init
                __index = function(self, i) self[i] = {}; return self[i] end
            }),
            nested_debug = setmetatable({} :: any, {
                __index = function(self, i: number) self[i] = {}; return self[i] end
            }),
            nested_stack = {}
        }
    end
end

local function return_caches(caches: typeof(free_caches) )
    free_caches = caches
end

-- map of datatype names to class default constructor for aggregate init
local aggregates = {}
for name, class in {
    CFrame = CFrame,
    Color3 = Color3,
    UDim = UDim,
    UDim2 = UDim2,
    Vector2 = Vector2,
    Vector3 = Vector3,
    Rect = Rect
} :: Map<string, { [string]: any }> do
    aggregates[name] = class.new
end

-- applies table of nested properties to an instance using full vide semantics
local function apply<T>(instance: T & Instance, properties: { [unknown]: unknown }): T
    if not properties then
        throw("attempt to call a constructor returned by create() with no properties")
    end

    local strict = flags.strict

    -- queue parent assignment if any for last
    local parent: unknown = properties.Parent 

    local caches = borrow_caches()
    local events = caches.events
    local actions = caches.actions
    local nested_debug = caches.nested_debug
    local nested_stack = caches.nested_stack

    -- process all properties
    local depth = 1
    repeat
        for property, value in properties do
            if property == "Parent" then continue end

            if type(property) == "string" then
                if strict then -- check for duplicate prop assignment at nesting depth
                    if nested_debug[depth][property] then
                        throw(`duplicate property {property} at depth {depth}`)
                    end
                    nested_debug[depth][property] = true
                end

                if type(value) == "table" then -- attempt aggregate init
                    local ctor = aggregates[typeof((instance :: any)[property])]
                    if ctor == nil then
                        throw(`cannot aggregate type {typeof(value)} for property {property}`)
                    end
                    (instance :: any)[property] = ctor(unpack(value :: {}))
                elseif type(value) == "function" then 
                    if typeof((instance :: any)[property]) == "RBXScriptSignal" then
                        events[property] = value  :: () -> () -- add event to buffer
                    else
                        bind.property(instance, property, value :: () -> ()) -- bind property
                    end
                else
                    (instance :: any)[property] = value -- set property
                end    
            elseif type(property) == "number" then
                if type(value) == "function" then
                    bind.children(instance, value :: () -> ArrayOrV<Instance>) -- bind children
                elseif type(value) == "table" then
                    if is_action(value) then
                        table.insert(actions[(value :: any).priority], (value :: any).callback :: () -> ()) -- add action to buffer
                    else
                        table.insert(nested_stack, value :: {})
                        table.insert(nested_stack, depth + 1) -- push table to stack for later processing
                    end
                else
                    (value :: Instance).Parent = instance -- parent child
                end
            end
        end

        depth = table.remove(nested_stack) :: number
        properties = table.remove(nested_stack) :: {}

    until not properties

    for event, listener in next, events do
        (instance :: any)[event]:Connect(listener)   
    end

    for _, queued in next, actions do
        for _, callback in next, queued do
            callback(instance)
        end
    end

    -- finally set parent if any
    if parent then
        if type(parent) == "function" then
            bind.parent(instance, parent :: () -> Instance)
        else
            instance.Parent = parent :: Instance
        end
    end

    -- clear caches
    table.clear(events)
    for _, queued in next, actions do table.clear(queued) end
    if strict then table.clear(nested_debug) end
    table.clear(nested_stack)

    return_caches(caches)

    return instance
end

return apply
