type Action = {
    priority: number,
    callback: (Instance) -> ()
}

local ActionMT = table.freeze {}

local function is_action(v: any)
    return getmetatable(v) == ActionMT
end

local function action(callback: (Instance) -> (), priority: number?): Action
    local a = {
        priority = priority or 1,
        callback = callback
    }

    setmetatable(a :: any, ActionMT)

    return table.freeze(a)
end

return function()
    return action, is_action
end
