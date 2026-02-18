if not game then script = require "test/relative-string" end

local function read<T>(value: T | () -> T): T
    return if type(value) == "function" then value() else value
end

return read
