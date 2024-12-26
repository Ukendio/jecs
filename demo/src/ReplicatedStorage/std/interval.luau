local function interval(s)
	local pin

	local function throttle()
		if not pin then
			pin = os.clock()
		end

		local elapsed = os.clock() - pin > s
		if elapsed then
			pin = os.clock()
		end

		return elapsed
	end
	return throttle
end

return interval