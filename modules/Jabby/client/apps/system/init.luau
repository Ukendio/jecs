local RunService = game:GetService("RunService")

local vide = require(script.Parent.Parent.Parent.vide)
local loop = require(script.Parent.Parent.Parent.modules.loop)
local remotes = require(script.Parent.Parent.Parent.modules.remotes)
local types = require(script.Parent.Parent.Parent.modules.types)
local widget = require(script.widget)

local cleanup = vide.cleanup

local system = {
	class_name = "app" :: "app",
	name = "System"
}

type props = {
	host: number,
	vm: number,
	scheduler: number,
	system: number,

	name: string

}

function system.mount(props: props, destroy: () -> ())

	local watch_id = math.random(2^31 - 1)
	local recording = vide.source(false)
	local watching_frame = vide.source(0)
	local per_frame_data = vide.source({} :: {[number]: number})
	local changes = vide.source({
		component = {},
		entities = {},
		types = {},
		values = {}
	} :: types.WatchLoggedChanges)

	local system_props_data = {
		watch_id = watch_id,
		host = props.host,
		vm = props.vm,
		scheduler = props.scheduler,
		system = props.system,
		name = props.name,

		changes = changes,
		recording = recording,
		per_frame_data = per_frame_data,
		watching_frame = watching_frame,
		destroy = destroy,
	}

	local app_loop = loop (
		"app-client-system",
		system_props_data,

		{i = 1},
		script.systems.replicate
	)

	local outgoing: types.OutgoingConnector = {
		host = system_props_data.host,
		to_vm = system_props_data.vm
	}

	remotes.create_watch:fire(outgoing, props.scheduler, props.system, watch_id)
	remotes.connect_watch:fire(outgoing, watch_id)

	cleanup(RunService.Heartbeat:Connect(app_loop))
	cleanup(function()
		remotes.disconnect_watch:fire(outgoing, watch_id)
		remotes.stop_watch:fire(outgoing, watch_id)
		remotes.remove_watch:fire(outgoing, watch_id)
	end)

	return widget(system_props_data)

end

return system