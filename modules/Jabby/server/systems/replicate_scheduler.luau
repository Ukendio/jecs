--!nolint LocalShadow
local hash = require(script.Parent.Parent.Parent.modules.hash_connector)
local queue = require(script.Parent.Parent.Parent.modules.queue)
local remotes = require(script.Parent.Parent.Parent.modules.remotes)
local reverse_connector = require(script.Parent.Parent.Parent.modules.reverse_connector)
local traffic_check = require(script.Parent.Parent.Parent.modules.traffic_check)
local types = require(script.Parent.Parent.Parent.modules.types)
local public = require(script.Parent.Parent.public)

return function()

	local connected = {}

	local request_scheduler = queue(remotes.request_scheduler)
	local disconnect_scheduler = queue(remotes.disconnect_scheduler)
	local schedule_pause = queue(remotes.scheduler_system_pause)

	return function()

		for incoming, id in request_scheduler:iter() do
			if not traffic_check.check_no_wl(incoming.host) then continue end

			local scheduler = public[id]

			if scheduler.class_name ~= "Scheduler" then continue end
			if scheduler == nil then continue end

			local outgoing = reverse_connector(incoming)
			connected[id] = connected[id] or {}
			table.insert(connected[id], outgoing)
			-- print("connected")
			
			for system_id, data in scheduler.system_data do
				remotes.scheduler_system_static_update:fire(outgoing, id, system_id, data)
			end

			for system_id, frames in scheduler.system_frames do
				local frame = frames[1]
				if not frame then continue end
				remotes.scheduler_system_update:fire(outgoing, id, system_id, frame.i, frame.s)
			end
		end

		for incoming, id in disconnect_scheduler:iter() do
			if not traffic_check.check_no_wl(incoming.host) then continue end

			if not connected[id] then continue end

			local scheduler_connected = connected[id]

			for i = #scheduler_connected, 1, -1 do
				local connector = scheduler_connected[i]
				if connector.host ~= incoming.host then continue end
				if connector.to_vm ~= incoming.from_vm then continue end
				scheduler_connected[i] = scheduler_connected[#scheduler_connected]
				scheduler_connected[#scheduler_connected] = nil
				break
			end
		end

		for incoming, id, system, paused in schedule_pause:iter() do
			if not traffic_check.check_no_wl(incoming.host) then continue end
			local scheduler: types.Scheduler = public[id]

			if not scheduler then return end

			scheduler:set_system_data(system, {
				paused = paused
			})
		end

		for id, connected in connected do
			local scheduler: types.Scheduler = public[id]
			if #connected == 0 then continue end
			
			for system_id in scheduler.system_data_updated do
				local map = {}
				local data = scheduler.system_data[system_id]

				for _, connector in connected do
					if map[hash(connector)] then continue end
					map[hash(connector)] = true
					remotes.scheduler_system_static_update:fire(connector, id, system_id, data)
				end
				
				scheduler.system_data_updated[system_id] = nil
			end

			for system_id, frames in scheduler.system_frames_updated do
				local map = {}
				for frame in frames do
					for _, connector in connected do
						if map[hash(connector)] then continue end
						map[hash(connector)] = true
						remotes.scheduler_system_update:fire(connector, id, system_id, frame.i, frame.s)
					end
				end
				table.clear(frames)
			end

		end

	end
end