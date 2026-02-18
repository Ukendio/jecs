local jecs = require(script.Parent.Parent.jecs)
type host = "client" | "server"

export type IncomingConnector = {
	host: Player | "server",
	from_vm: number,
	to_vm: number
}

export type OutgoingConnector = {
	host: Player | "server",
	to_vm: number?, -- not specifying a vm makes it received by all
	from_vm: nil
}

export type NetEvent<T...> = {

	type: "event",

	fire: (any, connector: OutgoingConnector, T...) -> (),
	connect: (any, callback: (connector: IncomingConnector, T...) -> ()) -> RBXScriptConnection,
}

export type NetCallback<T..., U...> = {

	type: "callback",

	invoke: (any, connector: OutgoingConnector, T...) -> U...,
	set_callback: (any, callback: (connector: IncomingConnector, T...) -> U...) -> (),
}

export type SystemId = number

export type SystemTag = "processing" | "finished" | "paused"
export type SystemSettingData = {
	name: string?,
	phase: string?,
	layout_order: number?,
	paused: boolean?
}
export type SystemData = {
	name: string,
	phase: string?,
	layout_order: number,
	paused: boolean
}

type ChangeTypes = "remove" | "clear" | "delete" | "add" | "set" | "entity" | "component"
export type WatchLoggedChanges = {
	types: {ChangeTypes},
	entities: {jecs.Entity<any>},
	component: {jecs.Entity<any>},
	values: {string},
	worlds: {jecs.World}
}

export type SystemWatch = {
	--- enables Lua Object Notation.
	--- incurs a significant performance penalty.
	enable_lon: boolean,
	--- the current frame to process
	frame: number,

	frames: {[number]: WatchLoggedChanges}
}

export type SystemLabel = {}

export type SystemFrame = {
	i: number,
	s: number
}

type WatchData = {active: boolean, watch: SystemWatch, untrack: () -> ()}

export type Scheduler = {
	class_name: "Scheduler",
	name: string,

	valid_system_ids: {[SystemId]: true},
	system_data: {[SystemId]: SystemData},
	system_data_updated: {[SystemId]: true},
	system_frames: {[SystemId]: SystemFrame},
	system_frames_updated: {[SystemId]: {[SystemFrame]: true}},
	system_watches: {[SystemId]: {WatchData}},

	register_system: (Scheduler, settings: SystemSettingData?) -> SystemId,
	set_system_data: (Scheduler, system: SystemId, settings: SystemSettingData) -> (),
	get_system_data: (Scheduler, system: SystemId) -> SystemSettingData,
	create_watch_for_system: (Scheduler, system: SystemId) -> WatchData,
	remove_system: (Scheduler, system: SystemId) -> (),

	-- mark_system_frame_start: (Scheduler, system: SystemId) -> (),
	-- mark_system_frame_end: (Scheduler, system: SystemId, s: number?) -> (),
	-- append_extra_frame_data: (Scheduler, system: SystemId, label: SystemLabel) -> (),
	--- this should call mark_system_frame_start and mark_system_frame_end for you
	run: <T...>(Scheduler, system: SystemId, system: () -> (), T...) -> (),

}

export type World = {
	class_name: "World",
	name: string,
	world: jecs.World,

	entities: {[Instance]: jecs.Entity<any>}?,
	get_entity_from_part: ((part: BasePart) -> (jecs.Entity<any>?, Part?))?
}

export type Application<T> = {
	class_name: "app",
	name: string,

	mount: (props: T, destroy: () -> ()) -> Instance
}

return nil