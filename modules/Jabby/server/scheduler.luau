local types = require(script.Parent.Parent.modules.types)
local watch = require(script.Parent.watch)

type SystemId = types.SystemId
type SystemSettingData = types.SystemSettingData
type SystemTag = types.SystemTag

type SystemData = types.SystemData
type ProcessingFrame = {
	started_at: number
}
type SystemFrame = types.SystemFrame

local MAX_BUFFER_SIZE = 50

local n = 0
local schedulers = {}

local function unit() end

local function create_scheduler()

	local count = 1
	local frames = 0

	local scheduler = {
		class_name = "Scheduler",
		name = "Scheduler",

		--- contains a map of valid system ids
		valid_system_ids = {} :: {[SystemId]: true},
		--- contains a list of static system data that is updated infrequently
		system_data = {} :: {[SystemId]: SystemData},
		--- list of system data that has updated
		system_data_updated = {} :: {[SystemId]: true},
		--- contains a buffer of the last couple frames of system data that is
		--- refreshed constantly
		system_frames = {} :: {[SystemId]: {SystemFrame}},
		--- stores the frames that have been updated
		system_frames_updated = {} :: {[SystemId]: {[SystemFrame]: true}},
		--- contains the current frame that a system is processing
		processing_frame = {} :: {[SystemId]: ProcessingFrame},
		--- contains a list of watches for each system
		system_watches = {} :: {[SystemId]: {{active: boolean, watch: types.SystemWatch}}}

	}

	local function ENABLE_WATCHES(id: SystemId)
		local watches = scheduler.system_watches[id]
		local cleanup = {}

		for i, system_watch in watches do
			if system_watch.active == false then continue end
			watch.step_watch(system_watch.watch)
			cleanup[i] = watch.track_watch(system_watch.watch)
		end

		return function()
			for _, stop in cleanup do
				stop()
			end
		end
	end

	local function ASSERT_SYSTEM_VALID(id: SystemId)
		assert(scheduler.valid_system_ids[id], `attempt to use unknown system with id #{id}`)
	end

	function scheduler:register_system(settings: types.SystemSettingData?)
		local id = count; count += 1
		scheduler.valid_system_ids[id] = true
		scheduler.system_data[id] = {
			name = "UNNAMED",
			phase = nil,
			layout_order = 0,
			paused = false
		}
		scheduler.system_frames[id] = {}
		scheduler.system_frames_updated[id] = {}
		
		if settings then
			scheduler:set_system_data(id, settings)
		end

		return id
	end

	function scheduler:set_system_data(id: SystemId, settings: types.SystemSettingData)
		ASSERT_SYSTEM_VALID(id)

		for key, value in settings do
			scheduler.system_data[id][key] = value
		end
		scheduler.system_data_updated[id] = true
	end

	function scheduler:get_system_data(id: SystemId)
		ASSERT_SYSTEM_VALID(id)
		return scheduler.system_data[id]
	end

	function scheduler:remove_system(id: SystemId)
		scheduler.valid_system_ids[id] = nil
		scheduler.system_data[id] = nil
		scheduler.system_frames[id] = nil
		scheduler.system_frames_updated[id] = nil
		scheduler.system_data_updated[id] = true
		scheduler.system_watches[id] = nil
	end

	function scheduler:_mark_system_frame_start(id: SystemId)
		ASSERT_SYSTEM_VALID(id)

		scheduler.processing_frame[id] = {
			started_at = os.clock()
		}
	end

	function scheduler:_mark_system_frame_end(id: SystemId, s: number?)
		ASSERT_SYSTEM_VALID(id)
		local now = os.clock()
		local pending_frame_data = scheduler.processing_frame[id]
		assert(pending_frame_data ~= nil, "no processing frame")
		local frame = {
			i = frames,
			s = now - pending_frame_data.started_at
		}

		frames += 1

		scheduler.processing_frame[id] = nil
		scheduler.system_frames_updated[id][frame] = true
		local last_frame = scheduler.system_frames[id][MAX_BUFFER_SIZE]
		if last_frame then
			scheduler.system_frames_updated[id][last_frame] = nil
		end

		table.insert(scheduler.system_frames[id], 1, frame)
		table.remove(scheduler.system_frames[id], MAX_BUFFER_SIZE + 1)
	end

	function scheduler:append_extra_frame_data(id: SystemId, label: {})
		--todo
		error("todo")
	end

	function scheduler:run<T...>(id: SystemId, system: (T...) -> (), ...: T...)
		ASSERT_SYSTEM_VALID(id)
		local system_data = scheduler.system_data[id]

		if system_data.paused then return end
		
		local watches = scheduler.system_watches[id]
		local cleanup_watches = unit

		if watches then
			cleanup_watches = ENABLE_WATCHES(id)
		end

		scheduler:_mark_system_frame_start(id)
		system(...)
		scheduler:_mark_system_frame_end(id)

		cleanup_watches()
	end

	function scheduler:create_watch_for_system(id: SystemId)
		ASSERT_SYSTEM_VALID(id)

		local new_watch = watch.create_watch()
		local watch_data
		scheduler.system_watches[id] = scheduler.system_watches[id] or {} :: never

		local function untrack()
			local idx = table.find(scheduler.system_watches[id], watch_data)
			table.remove(scheduler.system_watches[id], idx)
		end

		watch_data = {active = false, watch = new_watch, untrack = untrack}
		table.insert(scheduler.system_watches[id], watch_data)

		return watch_data
	end

	schedulers[n + 1] = scheduler
	n = n + 1

	return scheduler

end

return {

	create = create_scheduler,
	schedulers = schedulers

}