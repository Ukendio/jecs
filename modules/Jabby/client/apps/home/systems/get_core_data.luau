local Players = game:GetService("Players")

local vide = require(script.Parent.Parent.Parent.Parent.Parent.vide)
local queue = require(script.Parent.Parent.Parent.Parent.Parent.modules.queue)
local remotes = require(script.Parent.Parent.Parent.Parent.Parent.modules.remotes)
local reverse_connector = require(script.Parent.Parent.Parent.Parent.Parent.modules.reverse_connector)

return function(data)

	for _, player in Players:GetPlayers() do
		remotes.ping:fire({
			host = player,
		})
	end
	remotes.ping:fire({
		host = "server"
	})

	local servers_responding = queue(remotes.new_server_registered)
	local server_update = queue(remotes.update_server_data)
	local player_removing = queue(Players.PlayerRemoving)

	local n = 0
	local servers = data :: any
	local map_to_idx = {
		server = {}
	}

	return function()

		for connector in servers_responding:iter() do
			local outgoing = reverse_connector(connector)
			remotes.bind_to_server_core:fire(outgoing)
		end

		for	player in player_removing:iter() do
			local indexes = map_to_idx[player]

			if not indexes then continue end

			for _, idx in indexes do
				servers()[idx] = nil
			end
			servers(servers())
		end

		for connector, packet in server_update:iter() do
			local outgoing = reverse_connector(connector)

			map_to_idx[outgoing.host] = map_to_idx[outgoing.host] or {}
			local idx = map_to_idx[outgoing.host][outgoing.to_vm]

			if not idx then
				-- print("new server")
				idx = n + 1; n += 1
				map_to_idx[outgoing.host][outgoing.to_vm] = idx
				servers()[idx] = {
					host = outgoing.host,
					vm = outgoing.to_vm,

					schedulers = vide.source {},
					worlds = vide.source {}
				}
				servers(servers())
				-- print("set worlds")
				-- print(servers())
			end

			local server = servers()[idx]
			local schedulers = server.schedulers()
			local worlds = server.worlds()

			table.clear(schedulers)
			table.clear(worlds)

			for index, data in packet.schedulers do
				local at = schedulers[index]
				if at and at.name == data.name and at.id == data.id then continue end
				schedulers[index] = data
			end

			for index, data in packet.worlds do
				local at = worlds[index]
				if at and at.name == data.name and at.id == data.id then continue end
				worlds[index] = data
			end

			server.schedulers(schedulers)
			server.worlds(worlds)

		end
	end
end