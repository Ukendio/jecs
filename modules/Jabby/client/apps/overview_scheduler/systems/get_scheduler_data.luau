local vide = require(script.Parent.Parent.Parent.Parent.Parent.vide)
local queue = require(script.Parent.Parent.Parent.Parent.Parent.modules.queue)
local remotes = require(script.Parent.Parent.Parent.Parent.Parent.modules.remotes)
local types = require(script.Parent.Parent.Parent.Parent.Parent.modules.types)

local batch = vide.batch
local cleanup = vide.cleanup

type SystemId = types.SystemId
type SystemData = types.SystemData
type SystemFrame = types.SystemFrame

type context = {
	host: Player | "server",
	vm: number,
	id: number,
	
	system_ids: vide.Source<{[SystemId]: true}>,
	system_data: vide.Source<{[SystemId]: types.SystemData}>,
	system_frames: vide.Source<{[SystemId]: {types.SystemFrame}}>,
}

local MAX_BUFFER_SIZE = 50

return function(context: context)
	local outgoing = {
		host = context.host,
		to_vm = context.vm
	}

	remotes.request_scheduler:fire(outgoing, context.id)

	local scheduler_static_data_updated = queue(remotes.scheduler_system_static_update)
	local scheduler_frame_data_updated = queue(remotes.scheduler_system_update)

	cleanup(function()
		remotes.disconnect_scheduler:fire(outgoing, context.id)
	end)

	return function()

		batch(function()
			for incoming, scheduler, id, new_data in scheduler_static_data_updated:iter() do
				if incoming.host ~= context.host then continue end
				if incoming.from_vm ~= context.vm then continue end
				if scheduler ~= context.id then continue end

				if new_data == nil then
					context.system_ids()[id] = nil
					context.system_data()[id] = nil
					context.system_frames()[id] = nil

					context.system_ids(context.system_ids())
					context.system_data(context.system_data())
					context.system_frames(context.system_frames())
				else
					context.system_ids()[id] = true
					context.system_data()[id] = new_data
					context.system_frames()[id] = context.system_frames()[id] or {}

					context.system_ids(context.system_ids())
					context.system_data(context.system_data())
					context.system_frames(context.system_frames())
				end

			end

			for incoming, scheduler, id, f, s in scheduler_frame_data_updated:iter() do
				if incoming.host ~= context.host then continue end
				if incoming.from_vm ~= context.vm then continue end
				if scheduler ~= context.id then continue end
				if context.system_frames()[id] == nil then continue end

				-- look where to append the frame to
				local frames = context.system_frames()[id]
				local f_data = {i = f, s = s}
				local added = false

				--- since it's unreliable we have to constantly check if we arent out of order
				for i, frame in frames do
					if frame.i == f then frames[i] = f_data; continue end
					if frame.i > f then continue end
					table.insert(frames, i, f_data)
					table.remove(frames, MAX_BUFFER_SIZE + 1)
					added = true
					break
				end

				if #frames <= MAX_BUFFER_SIZE and added == false then
					table.insert(frames, f_data)
				end
				
				context.system_frames(context.system_frames())
			end
		end)

	end
end