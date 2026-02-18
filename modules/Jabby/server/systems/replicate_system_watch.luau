--[[

Handles the API for the system watch.
Users will be able to add watches to their systems to track changes.

Users will be able to learn about what actions a system performs on a jecs world
through this.

Hooked API's:

component()
entity()
remove()
clear()
delete()
add()
set()

]]

local jecs = require(script.Parent.Parent.Parent.jecs)
local hash_connector = require(script.Parent.Parent.Parent.modules.hash_connector)
local lon = require(script.Parent.Parent.Parent.modules.lon)
local queue = require(script.Parent.Parent.Parent.modules.queue)
local remotes = require(script.Parent.Parent.Parent.modules.remotes)
local reverse_connector = require(script.Parent.Parent.Parent.modules.reverse_connector)
local types = require(script.Parent.Parent.Parent.modules.types)
local public = require(script.Parent.Parent.public)
local watch = require(script.Parent.Parent.watch)

local NIL = watch.NIL

return function()

	local stored_watches = {}
	local connected_watches = {}

	local function create_watch_for_id(
		scheduler: types.Scheduler,
		system: types.SystemId,
		watch_id: number
	)
		local watch = scheduler:create_watch_for_system(system)
		stored_watches[watch_id] = watch
	end

	local function send_watch_data_to(host: types.OutgoingConnector, watch_id: number, frame: number)
		local map_worlds_to_name = {}
		local watch = stored_watches[watch_id]
		local frames = watch.watch.frames
		local data = frames[frame]

		if not data then
			remotes.update_watch_data:fire(host, watch_id, frame, nil)
			return
		end

		for _, world in ipairs(public) do
			if world.world == nil then continue end
			map_worlds_to_name[world.world] = jecs.Name
		end

		local to_send = {
			types = data.types,
			entities = data.entities,
			component = table.clone(data.component),
			values = table.clone(data.values)
		}

		for idx, ctype in to_send.component do
			local world = data.worlds[idx]
			to_send.component[idx] = world:get(ctype, map_worlds_to_name[world]) or ctype
		end

		for idx, value in to_send.values do
			if value == NIL then to_send.values[idx] = "" end
			to_send.values[idx] = lon.output(value, false)
		end

		remotes.update_watch_data:fire(host, watch_id, frame, to_send :: any)
	end

	local function remove_watch_id(watch_id: number)
		if not stored_watches[watch_id] then return end
		stored_watches[watch_id].untrack()
		stored_watches[watch_id] = nil
		connected_watches[watch_id] = nil
	end

	local function start_record_watch(watch_id: number)
		local watch = stored_watches[watch_id]
		watch.active = true
	end

	local function stop_record_watch(watch_id: number)
		local watch = stored_watches[watch_id]
		watch.active = false
	end

	local function connect_watch(host: types.OutgoingConnector, watch_id: number)
		connected_watches[watch_id] = connected_watches[watch_id] or {}
		connected_watches[watch_id][hash_connector(host)] = host

		local watch = stored_watches[watch_id]
		for i, frame in watch.watch.frames do
			remotes.update_overview:fire(host, watch_id, i, #frame.types)
		end
	end

	local function disconnect_watch(host: types.OutgoingConnector, watch_id: number)
		if not connected_watches[watch_id] then return end
		connected_watches[watch_id][hash_connector(host)] = nil
	end

	local request_create_watch = queue(remotes.create_watch)	
	local request_remove_watch = queue(remotes.remove_watch)
	local request_watch_data = queue(remotes.request_watch_data)
	local request_stop_watch = queue(remotes.stop_watch)
	local request_record_watch = queue(remotes.start_record_watch)
	local request_connect_watch = queue(remotes.connect_watch)
	local request_disconnect_watch = queue(remotes.disconnect_watch)
	-- local set_lon_enabled = queue(remotes.set_lon_enabled)

	return function()

		for from, scheduler_id, system, watch_id in request_create_watch:iter() do
			local scheduler = public[scheduler_id]

			if scheduler.class_name ~= "Scheduler" then continue end
			if scheduler == nil then continue end
			
			create_watch_for_id(scheduler, system, watch_id)
		end

		for from, watch_id in request_stop_watch:iter() do
			stop_record_watch(watch_id)
		end

		for from, watch_id in request_remove_watch:iter() do
			remove_watch_id(watch_id)
		end

		for from, watch_id, frame in request_watch_data:iter() do
			send_watch_data_to(
				reverse_connector(from),
				watch_id,
				frame
			)
		end

		for from, watch_id in request_record_watch:iter() do
			start_record_watch(watch_id)
		end

		for from, watch_id in request_connect_watch:iter() do
			connect_watch(reverse_connector(from), watch_id)
		end

		for from, watch_id in request_disconnect_watch:iter() do
			disconnect_watch(from, watch_id)
		end

		for watch_id, hosts in connected_watches do
			local watch = stored_watches[watch_id]
			local current_frame = watch.watch.frame
			local frame_data = watch.watch.frames[current_frame] or {types = {}}
			local changes = #frame_data.types

			for _, host in hosts do
				remotes.update_overview:fire(host, watch_id, current_frame, changes)
			end
		end

	end
end