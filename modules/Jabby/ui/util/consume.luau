--[[

Consumes a property from a table and removes it

]]

return function(t: {}, key: string)
    local v = t[key]; t[key] = nil
    return v
end