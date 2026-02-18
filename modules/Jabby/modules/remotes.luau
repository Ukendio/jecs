local jecs = require(script.Parent.Parent.jecs)
local net = require(script.Parent.net)
local types = require(script.Parent.types)

--todo: redo this file
type Query = {
	include: { jecs.Entity<any> },
	exclude: { jecs.Entity<any> },
	with: { jecs.Entity<any> },
}

return {

	--[=[
	Broadcasts to clients that a new server has been registered.
	Accepts no params.
	]=]
	new_server_registered = net.create_event("server_registered", false, true)
		:: types.NetEvent<>,

	--[=[
	Pings all servers and make them respond with new_server_registered
	]=]
	ping = net.create_event("ping", false, true)
		:: types.NetEvent<>,

	--[=[
	Broadcasts to servers that a new client has been registered
	Accepts no params.
	]=]
	bind_to_server_core = net.create_event("client_registered")
		:: types.NetEvent<>,

	--[=[
	Sends a update to a client about a new server
	]=]
	update_server_data =
		net.create_event("update_server_data")
		:: types.NetEvent<{
			worlds: {{id: number, name: string}},
			schedulers: {{id: number, name: string}}	
		}>,

	--[=[
	The client will use this to send the mouse pointer to the server
	]=]
	send_mouse_pointer =
		net.create_event("send_mouse_pointer")
		:: types.NetEvent<number, Vector3, Vector3>,

	--[[
	
	
	]]
	send_mouse_entity = 
		net.create_event("send_mouse_entity", true)
		:: types.NetEvent<number, Part?, number?, string?>,

	--[=[
	Requests the server to validate a query
	world: number
	query: string
	]=]
	validate_query =
		net.create_event("validate_query")
		:: types.NetEvent<number, string>,

	--[=[
	Result of the validation
	world: number query: string, terms: {}, ok: boolean, message: string?
	]=]
	validate_result =
		net.create_event("validate_result")
		:: types.NetEvent<number, string, Query?, boolean, string?>,

	--[=[
	Requests a server to initiate replication of a query.
	
	world: number
	id: number
	query_id: number
	query: string
	]=]
	request_query =
		net.create_event("replicate_query")
		:: types.NetEvent<number, number, string>,

	--[=[
	Disconnects query

	query_id: number
	]=]
	disconnect_query =
		net.create_event("disconnect_query")
		:: types.NetEvent<number>,
	
	--[=[
	Changes the offsets to query for

	query_id: number
	from: number
	to: number
	]=]
	advance_query_page =
		net.create_event("advance_query_page")
		:: types.NetEvent<number, number, number>,

	--- pause the query
	--- query id
	--- should pause
	pause_query = 
		net.create_event("pause_query")
		:: types.NetEvent<number, boolean>,

	--- refreshes query results
	--- query_id
	refresh_results = 
		net.create_event("refresh_query")
		:: types.NetEvent<number>,

	--[=[
	Updates a single result
	
	query_id: number
	frame: number
	column: number
	row: number
	value: any
	]=]
	update_query_result =
		net.create_event("update_query_result", true)
		:: types.NetEvent<(number, number, number, number, any)>,

	--[=[
	Counts the total number of entities

	query id: number
	count: number
	]=]

	count_total_entities =
		net.create_event("count_total_entities", true)
		:: types.NetEvent<number, number>,

	--[=[
	Requests a server to initiate replication of a scheduler
	]=]
	request_scheduler =
		net.create_event("initiate_replicate_scheduler") ::
		types.NetEvent<number>,

	--[=[
	Requests the server to stop replicating a scheduler
	]=]
	disconnect_scheduler =
		net.create_event("disconnect_replicate_scheduler") ::
		types.NetEvent<number>,

	--[=[
	Updates any static data about systems (like new systems)

	systemid: number
	static_data: {}
	]=]
	scheduler_system_static_update =
		net.create_event("scheduler_system_update_static") ::
		types.NetEvent<number, number, types.SystemData?>,

	--[=[
	Appends a frame to a system
	
	systemid: number
	frame_count: number
	time_took: number
	]=]
	scheduler_system_update =
		net.create_event("append_frame_system", true) ::
		types.NetEvent<number, number, number, number>,

	--[=[
	Pauses a system
	
	scheduler: number
	systemid: number
	paused: boolean
	]=]
	scheduler_system_pause =
		net.create_event("scheduler_pause") ::
		types.NetEvent<number, number, boolean>,

	--[[
	Validates a component

	world: number
	component: string
	]]
	validate_entity_component =
		net.create_event("validate_entity_component") ::
		types.NetEvent<number, string>,

	--[[
	entity component reslt
	
	world: number
	component: string
	ok: boolean
	reason: string
	]]
	validate_entity_component_result =
		net.create_event("validate_entity_component_result") ::
		types.NetEvent<number, string, boolean, string>,

	--[[
	Inspect a entity's components

	world: number
	entity: number,
	inspectid: number
	]]

	inspect_entity =
		net.create_event("inspect_entity") ::
		types.NetEvent<number, number, number>,

	--[=[
	Gets the component of an entity
	
	inspect: number
	component: string
	]=]
	get_component =
		net.create_event("get_entity_component") ::
		types.NetEvent<number, string>,
		
	--[=[
	Returns the component of an entity
	
	inspect: number
	component: string
	value: string
	]=]
	return_component =
		net.create_event("return_entity_component") ::
		types.NetEvent<number, string, string>,

	--[[
	Delete entity
	
	inspectid: number
	]]
	delete_entity =
		net.create_event("delete_entity") ::
		types.NetEvent<number>,
	
	--[[
	Stops inspecting a entity

	inspectid: number
	]]
	stop_inspect_entity =
		net.create_event("stop_inspect_entity") ::
		types.NetEvent<number>,

	--[[
	Updates a entity
	
	inspectid: number
	changes: {[component]: string}
	]]
	update_entity =
		net.create_event("update_entity") ::
		types.NetEvent<number, {[string]: string}>,

	--[[
	Update the settings when dealing with inspecting
	
	inspectid: nuimber,
	settings: {}
	]]
	update_inspect_settings =
		net.create_event("inspect_entity_settings_update") ::
		types.NetEvent<number, {paused: boolean}>,

	--[[
	Inspector update
	
	inspectid: number
	key: string
	value: string
	]]
	inspect_entity_update =
		net.create_event("inspect_entity_update") ::
		types.NetEvent<number, string, string?>,
	
	--[[
	Creates a watch on a system
	
	scheduler: number,
	system: number
	watchid: number
	]]
	create_watch =
		net.create_event("create_watch") ::
		types.NetEvent<number, number, number>,
	
	--[[
	Removes a watch on a system

	watchid: number
	]]
	remove_watch =
		net.create_event("remove_watch") ::
		types.NetEvent<number>,
	
	--[[
	Retrieves data about a frame for a watch
	
	watchid: number
	frame: number
	]]
	request_watch_data =
		net.create_event("request_watch_data") ::
		types.NetEvent<number, number>,

	--[[
	Updates watch data for a frame
	
	watchid: number
	frame: number
	changes: types.WatchLoggedChanges
	]]
	update_watch_data =
		net.create_event("update_watch_data") ::
		types.NetEvent<number, number, types.WatchLoggedChanges?>,

	start_record_watch =
		net.create_event("start_record_watch") ::
		types.NetEvent<number>,

	stop_watch =
		net.create_event("stop_watch") ::
		types.NetEvent<number>,

	clear_watch =
		net.create_event("clear_watch") ::
		types.NetEvent<number>,

	connect_watch =
		net.create_event("connect_to_watch") ::
		types.NetEvent<number>,
	
	disconnect_watch = 
		net.create_event("disconnect_watch") ::
		types.NetEvent<number>,

	update_overview =
		net.create_event("update_watch_overview", true) ::
		types.NetEvent<number, number, number>
}