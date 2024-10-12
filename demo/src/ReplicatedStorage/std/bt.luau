--!optimize 2
--!native

-- original author @centau

local SUCCESS = 0
local FAILURE = 1
local RUNNING = 2

local function SEQUENCE(nodes)
	return function(...)
		for _, node in nodes do
			local status = node(...)
			if status == FAILURE or status == RUNNING then
				return status
			end
		end
		return SUCCESS
	end
end

local function FALLBACK(nodes)
	return function(...)
		for _, node in nodes do
			local status = node(...)
			if status == SUCCESS or status == RUNNING then
				return status
			end
		end
		return FAILURE
	end
end

local bt = {
	SEQUENCE = SEQUENCE,
	FALLBACK = FALLBACK,
	RUNNING = RUNNING,
}

return bt
