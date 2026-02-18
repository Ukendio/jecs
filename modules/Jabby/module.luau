local jecs = require(script.Parent.jecs)
local traffic_check = require(script.Parent.modules.traffic_check)
local types = require(script.Parent.modules.types)
local vm_id = require(script.Parent.modules.vm_id)
local server = require(script.Parent.server)
local public = require(script.Parent.server.public)
local scheduler = require(script.Parent.server.scheduler)

type Applet<T> = {
	add_to_public: (name: string, config: T) -> ()
}

local world_applet = {
	add_to_public = function(
		name: string, config: { world: jecs.World, entities: {[Instance]: jecs.Entity<any>}?, get_entity_from_part: ((part: BasePart) -> (jecs.Entity<any>, Part?))? }
	)
		public.updated = true
		table.insert(public, {
			class_name = "World",
			name = name,
			world = config.world,
			entities = config.entities,
			get_entity_from_part = config.get_entity_from_part
		})
	end
}

local scheduler_applet = {
	add_to_public = function(
		name: string, config: { scheduler: types.Scheduler }
	)
		public.updated = true
		config.scheduler.name = name
		table.insert(public, config.scheduler)
	end
}

return {
	set_check_function = function(callback: (Player) -> boolean)
		traffic_check.can_use_jabby = callback
	end,

	obtain_client = function()
		return require(script.Parent.client)
	end,

	vm_id = vm_id,
	scheduler = scheduler,

	broadcast_server = server.broadcast,

	applets = {
		world = world_applet,
		scheduler = scheduler_applet
	},

	register = function<T>(info: { name: string, applet: Applet<T>, configuration: T })
		info.applet.add_to_public(info.name, info.configuration)
	end,
}
