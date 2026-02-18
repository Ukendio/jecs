

local function average(n: {number})
	local sum = 0
	for i, v in n do
		sum += v
	end
	return sum / #n
end

return average