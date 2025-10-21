local function component()
	local id = 1
	local v
	local function instance()
		return id, v
	end
	return function(value)
		v = value
		return instance
	end
end
