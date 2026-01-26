-- original author @centau

local SUCCESS = true
local FAILURE = false
local RUNNING = newproxy(false)

local function SEQUENCE(nodes: { (...any) -> boolean})
	return function(...)
		for _, node in nodes do
			local status = node(...)
			if not status or status == RUNNING then
				return status
			end
		end
		return SUCCESS
	end
end

local function FALLBACK(nodes: { (...any) -> boolean })
	return function(...)
		for _, node in nodes do
			local status = node(...)
			if status or status == RUNNING then
				return status
			end
		end
		return FAILURE
	end
end

local function NOT(f)
	return function(...): boolean
		return not f(...)
	end
end

local bt = {
	SEQUENCE = SEQUENCE,
	FALLBACK = FALLBACK,
	RUNNING = RUNNING,
	NOT = NOT,
}

return bt