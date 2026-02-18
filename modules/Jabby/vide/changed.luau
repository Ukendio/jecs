if not game then script = require "test/relative-string" end

local action = require(script.Parent.action)()
local cleanup = require(script.Parent.cleanup)

local function changed<T>(property: string, callback: (T) -> ())
    return action(function(instance)
        local con = instance:GetPropertyChangedSignal(property):Connect(function()
            callback((instance :: any)[property])
        end)

        cleanup(function()
            con:Disconnect()
        end)

        callback((instance :: any)[property])
    end)
end

return changed
