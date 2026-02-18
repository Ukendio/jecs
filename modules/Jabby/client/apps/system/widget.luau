local ui = require(script.Parent.Parent.Parent.Parent.ui)
local vide = require(script.Parent.Parent.Parent.Parent.vide)
local types = require(script.Parent.Parent.Parent.Parent.modules.types)
local watch_tracker = require(script.Parent.watch_tracker)

type props = {
	host: "server" | Player,
	vm: number,

	scheduler: number,
	system: number,
	name: string,

	destroy: () -> (),

	recording: vide.Source<boolean>,
	watching_frame: vide.Source<number>,
	per_frame_data: () -> {[number]: number},
	changes: () -> types.WatchLoggedChanges,
}

return function(props: props)

	return ui.widget {
		title = `system - {props.name}`,
		subtitle = `host: {props.host} vm: {props.vm} scheduler: {props.scheduler} system: {props.system}`,
		bind_to_close = props.destroy,
		size = Vector2.new(350, 400),
		min_size = Vector2.new(300, 300),

		watch_tracker(props)
	}

end