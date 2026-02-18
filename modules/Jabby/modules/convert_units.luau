local function convert_units(unit: string, value: number): (string)
	local s = math.sign(value)
	value = math.abs(value)
    local prefixes = {
        [4] = "T",
        [3] ="G",
        [2] ="M",
        [1] = "k",
        [0] = " ",
        [-1] = "m",
        [-2] = "u",
        [-3] = "n",
        [-4] = "p"
    }

    local order = 0
    
    while value >= 1000 do
        order += 1
        value /= 1000
    end

    while value ~= 0 and value < 1 do
        order -= 1
        value *= 1000
    end

    if value >= 100 then
        value = math.floor(value)
    elseif value >= 10 then
        value = math.floor(value * 1e1) / 1e1
    elseif value >= 1 then
        value = math.floor(value * 1e2) / 1e2
    end

    return value * s .. prefixes[order] .. unit
end

return convert_units