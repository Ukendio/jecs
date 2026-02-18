local RunService = game:GetService("RunService")

local vide = require(script.Parent.Parent.Parent.vide)
local loop = require(script.Parent.Parent.Parent.modules.loop)
local remotes = require(script.Parent.Parent.Parent.modules.remotes)
local widget = require(script.widget)

local source = vide.source
local cleanup = vide.cleanup

local overview_scheduler = {
	class_name = "app" :: "app",
	name = "Scheduler"
}

type props = {
	host: Player | "server",
	vm: number,
	id: number
}

function overview_scheduler.mount(props: props, destroy: () -> ())

	local system_data = source {}
	local system_frames = source {}
	local system_ids = source {}

	local app_loop = loop (
		"app-client-scheduler",
		{
			host = props.host,
			vm = props.vm,
			id = props.id,

			system_ids = system_ids,
			system_data = system_data,
			system_frames = system_frames,
		},

		{i = 1},
		script.systems.get_scheduler_data
	)

	cleanup(
		RunService.Heartbeat:Connect(app_loop)
	)

	return widget {
		host = props.host,
		vm = props.vm,
		id = props.id,

		system_ids = system_ids,
		system_data = system_data,
		system_frames = system_frames,
		pause_system = function(system: number)
			remotes.scheduler_system_pause:fire({
				host = props.host,
				to_vm = props.vm
			}, props.id, system, not system_data()[system].paused)
		end,
		
		destroy = destroy
	}

end

return overview_scheduler