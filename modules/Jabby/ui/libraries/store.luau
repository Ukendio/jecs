--------------------------------------------------------------------------------
-- videx/store.luau
--------------------------------------------------------------------------------

local vide = require(script.Parent.Parent.Parent.vide)
local source = vide.source

local NULL = newproxy()

local Store = {}

--[=[
Creates a new store object that receives some initial state and then returns
a table with the same structure, but all keys of the given table will be reactive.

When accessed inside a reactive scope, the reactive scope will update whenever
the key that is accessed is changed.

@param initial_state `T : {[string]: any}` The initial state the store will start in.
@param mutations `() -> {[string]: (T, ...any) -> ...any}?` A list of functions that mutate the data.
@return `T & U` A resulting table that 
]=]
function Store.new<T, U>(
    initial_state: T & {},
    mutations: (T & U) -> U
): T & U
    local sources = {}

    for i, v in initial_state :: any do
        local src = source(v ~= NULL and v or nil)
        sources[i] = src
    end

    local internal_proxy = {}

    setmetatable(internal_proxy, {
        __index = function(_, index)
            return sources[index]()
        end,
        __newindex = function(_, index, value)
            sources[index](value)
        end
    })

    local external_proxy = {}

    setmetatable(external_proxy :: any, {
        __index = function(_, index)
            local src = sources[index]
            if src == nil then error(`invalid index {index}`, 2) end
            return src()
        end,

        __newindex = function(_, index, value)
            sources[index](value)
        end
    })

    for i, v in next, mutations(internal_proxy :: any) :: any do
        if rawget(external_proxy, i) then
            error(`duplicate field "{i}"`, 2)
        end
        rawset(external_proxy, i, v)
    end

    return external_proxy :: T & U & {}
end


--[=[
Creates a new store object that receives some initial state and then returns
a table with the same structure, but all keys of the given table will be reactive.

When accessed inside a reactive scope, the reactive scope will update whenever
the key that is accessed is changed.

@param initial_state `T : {[string]: any}` The initial state the store will start in.
@param mutations `() -> {[string]: (T, ...any) -> ...any}?` A list of functions that mutate the data.
@return `T & U` A resulting table that 
]=]
function Store.new_deep<T, U>(
    initial_state: T & {},
    mutations: (T & U) -> U
): T & U
    
    local main = Store.new(initial_state, mutations)

    for key, value in initial_state :: any do
        if type(value) == "table" then
            main[key] = Store.new_deep(value, mutations :: any)
        end
    end

    return main

end

--- A special symbol used to indicate that a value should be nil within a Store.
Store.null = NULL :: nil

return Store