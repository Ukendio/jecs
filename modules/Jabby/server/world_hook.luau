
local public = require(script.Parent.public)

local function i_hook_onto(key: string, hooks: {(...any) -> ()})

	local to_unhook = {}
	for _, world_data in ipairs(public) do
		local world = world_data.world
		if not world then continue end

		local method: any = world[key]

		assert(typeof(method) == "function", "can only hook onto functions")

		-- create a new wrapper function
		local function run_hook(...)
			for _, hook in hooks do
				hook(...)
			end
			return method(...)
		end

		-- print(debug.info(world[key], "s"))
		world[key] = run_hook
		to_unhook[world] = method
	end
	
	return function()
		for world, method in to_unhook do
			world[key] = method
		end
	end
end

local hooks = {}

local function find_swap_pop<T>(list: {T}, value: T)
	local idx = table.find(list, value)
	if not idx then return end
	list[idx] = list[#list]
	list[#list] = nil
end

local function hook_onto(key: string, hook: (...any) -> ())

	if hooks[key] == nil then
		local callbacks = {}
		local cleanup = i_hook_onto(key, callbacks)
		hooks[key] = {
			cleanup = cleanup,
			callbacks = callbacks
		}
	end

	local hook_info = hooks[key]
	local dead = false
	table.insert(hook_info.callbacks, hook)

	local function unhook()
		if dead then return end
		dead = true
		find_swap_pop(hook_info.callbacks, hook)
		
		if hook_info.callbacks[1] == nil then
			hook_info.cleanup()
			hooks[key] = nil
		end
	end

	return unhook
end

return {
	hook_onto = hook_onto
}