if not game then script = require "test/relative-string" end

local switch = require(script.Parent.switch)

local function show<T>(source: () -> any, component: () -> T, fallback: (() -> T)?): () -> T?
    local function truthy()
        return not not source()
    end

    return switch(truthy) {
        [true] = component,
        [false] = fallback,
    }
end

return show ::
    (<T>(source: () -> any, component: () -> T) -> () -> T?) &
    (<T, U>(source: () -> any, component: () -> T, fallback: () -> U) -> () -> (T | U)?)
