local types = require(script.Parent.Parent.modules.types)
local world_hook = require(script.Parent.world_hook)

local NIL = newproxy()

type ChangeTypes = "remove" | "clear" | "delete" | "add" | "set" | "entity" | "component"
type Changes = types.WatchLoggedChanges

export type SystemWatch = {
	--- enables Lua Object Notation.
	--- incurs a significant performance penalty.
	enable_lon: boolean,
	--- the current frame to process
	frame: number,

	frames: {[number]: Changes}
}

local function create_changes()
	return {
		types = {},
		entities = {},
		component = {},
		values = {},
		worlds = {}
	}
end

local function step_watch(watch: SystemWatch)
	watch.frame += 1
	watch.frames[watch.frame] = create_changes()
end

local function track_watch(watch: SystemWatch)

	local hooks = {

		world_hook.hook_onto("remove", function(self, id, component)
			local frame = watch.frames[watch.frame]
			
			table.insert(frame.types, "remove")
			table.insert(frame.entities, id)
			table.insert(frame.component, component)
			table.insert(frame.values, NIL)
			table.insert(frame.worlds, self)
		end),
	
		world_hook.hook_onto("clear", function(self, id)
			local frame = watch.frames[watch.frame]
			
			table.insert(frame.types, "clear")
			table.insert(frame.entities, id)
			table.insert(frame.component, NIL)
			table.insert(frame.values, NIL)
			table.insert(frame.worlds, self)
		end),
	
		world_hook.hook_onto("delete", function(self, id)
			local frame = watch.frames[watch.frame]
			
			table.insert(frame.types, "delete")
			table.insert(frame.entities, id)
			table.insert(frame.component, NIL)
			table.insert(frame.values, NIL)
			table.insert(frame.worlds, self)
		end),
	
		world_hook.hook_onto("add", function(self, id, component)
			local frame = watch.frames[watch.frame]
			
			table.insert(frame.types, "add")
			table.insert(frame.entities, id)
			table.insert(frame.component, component)
			table.insert(frame.values, NIL)
			table.insert(frame.worlds, self)
		end),
		
		world_hook.hook_onto("set", function(self, entity, component, value)
			if self:has(entity, component) then
				local frame = watch.frames[watch.frame]
				
				table.insert(frame.types, "change")
				table.insert(frame.entities, entity)
				table.insert(frame.component, component)
				table.insert(frame.values, value)
				table.insert(frame.worlds, self)
			else
				local frame = watch.frames[watch.frame]
				
				table.insert(frame.types, "move")
				table.insert(frame.entities, entity)
				table.insert(frame.component, component)
				table.insert(frame.values, value)
				table.insert(frame.worlds, self)
			end
		end)

	}
	
	--- stops all hooks
	local function stop_hook()
		for _, destroy in hooks do
			destroy()
		end
	end

	return stop_hook
end

local function create_watch()
	local watch: SystemWatch = {
		enable_lon = false,

		frame = 0,
		frames = {}
	}

	return watch
end

return {

	create_watch = create_watch,
	track_watch = track_watch,
	step_watch = step_watch,

	NIL = NIL

}