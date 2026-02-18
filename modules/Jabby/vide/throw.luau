if not game then script = require "test/relative-string" end

local function VIDE_ASSERT(msg): any
    error(msg, 0)
end

return VIDE_ASSERT
