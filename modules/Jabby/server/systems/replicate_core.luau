local queue = require(script.Parent.Parent.Parent.modules.queue)
local remotes = require(script.Parent.Parent.Parent.modules.remotes)
local reverse_connector = require(script.Parent.Parent.Parent.modules.reverse_connector)
local traffic_check = require(script.Parent.Parent.Parent.modules.traffic_check)
local public = require(script.Parent.Parent.public)

return function()

	local connected = {}

	local bind_to_core = queue(remotes.bind_to_server_core)

	return function()

		for connector in bind_to_core:iter() do
			local outgoing = reverse_connector(connector)
			
			if not traffic_check.check_no_wl(connector.host) then continue end
			-- print("help")

			table.insert(connected, outgoing)
			local schedulers = {}
			local worlds = {}

			for idx, data in ipairs(public) do

				if data.class_name == "Scheduler" then
					table.insert(schedulers, {
						name = data.name :: string,
						id = idx
					})
				elseif data.class_name == "World" then
					table.insert(worlds, {
						name = data.name :: string,
						id = idx
					})
				end

			end

			remotes.update_server_data:fire(outgoing, {
				schedulers = schedulers,
				worlds = worlds
			})
		end

		if public.updated == false then return end
		public.updated = false
		
		local schedulers = {}
		local worlds = {}

		for idx, data in ipairs(public) do

			if data.class_name == "Scheduler" then
				table.insert(schedulers, {
					name = data.name :: string,
					id = idx
				})
			elseif data.class_name == "World" then
				table.insert(worlds, {
					name = data.name :: string,
					id = idx
				})
			end

		end

		local fired_to = {}
		for _, connector in connected do
			if fired_to[connector] then return end
			fired_to[connector] = true
			remotes.update_server_data:fire(connector, {
				schedulers = schedulers,
				worlds = worlds
			})
		end

	end
end