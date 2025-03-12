local events = {}

local function trackers_invoke(event, component, entity, ...)
	local trackers = events[event][component]
	if not trackers then
		return
	end

	for _, tracker in trackers do
		tracker(entity, data)
	end
end

local function trackers_init(event, component, fn)
	local ob = events[event]

	return {
		connect = function(component, fn)
			local trackers = ob[component]
			if not trackers then
				trackers = {}
				ob[component] = trackers
			end

			table.insert(trackers, fn)
		end,
		invoke = function(component, ...)
			trackers_invoke(event, component, ...)
		end
	}
	return function(component, fn)
		local trackers = ob[component]
		if not trackers then
			trackers = {}
			ob[component] = trackers
		end

		table.insert(trackers, fn)
	end
end

local trackers = {
	emplace = trackers_init("emplace"),
	add = trackers_init("added"),
	remove = trackers_init("removed")
}

return trackers
