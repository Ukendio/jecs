local vide = require(script.Parent.Parent.Parent.Parent.Parent.vide)
local queue = require(script.Parent.Parent.Parent.Parent.Parent.modules.queue)
local remotes = require(script.Parent.Parent.Parent.Parent.Parent.modules.remotes)
local types = require(script.Parent.Parent.Parent.Parent.Parent.modules.types)

local batch = vide.batch

type Context = {
	host: "server" | Player,
	vm: number,

	watch_id: number,
	scheduler: number,
	system: number,
	name: string,

	recording: vide.Source<boolean>,
	watching_frame: vide.Source<number>,
	per_frame_data: vide.Source<{[number]: number}>,
	changes: (types.WatchLoggedChanges) -> (),
}

return function(context: Context)

	local watch_id = context.watch_id
	local outgoing: types.OutgoingConnector = {
		host = context.host,
		to_vm = context.vm
	}

	local recording_state_changed = false
	local recording = false

	vide.effect(function()
		recording_state_changed = true
		recording = context.recording()
	end)

	local watching_frame_changed = false
	local watching_frame = 1
	vide.effect(function()
		watching_frame_changed = true
		watching_frame = context.watching_frame()
	end)

	local receive_update_data = queue(remotes.update_watch_data)
	local receive_overview = queue(remotes.update_overview)

	return function()

		if recording_state_changed and recording then
			remotes.start_record_watch:fire(outgoing, watch_id)
			recording_state_changed = false
		elseif recording_state_changed and not recording then
			remotes.stop_watch:fire(outgoing, watch_id)
			recording_state_changed = false
		end

		if watching_frame_changed then
			remotes.request_watch_data:fire(outgoing, watch_id, watching_frame)
			watching_frame_changed = false
		end

		debug.profilebegin("receive update data")
		batch(function()
			for from, watch, frame, changes in receive_update_data:iter() do
				if watch ~= watch_id then continue end
				if frame ~= watching_frame then continue end
				if changes == nil then
					context.changes({
						types = {},
						entities = {},
						component = {},
						values = {},
						worlds = {}
					})
				else
					context.changes(changes)
				end
			end
		end)
		debug.profileend()

		debug.profilebegin("receive overview")
		batch(function()
			for from, watch, frame, value in receive_overview:iter() do
				if watch ~= watch_id then continue end
				local data = context.per_frame_data()
				if data[frame] == value then continue end
				data[frame] = value
				context.per_frame_data(data)
			end
		end)
		debug.profileend()
		
	end
end