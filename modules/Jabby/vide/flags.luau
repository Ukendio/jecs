local function inline_test(): string
    return debug.info(1, "n")
end

local is_O2 = inline_test() ~= "inline_test"

return { strict = not is_O2, batch = false }
