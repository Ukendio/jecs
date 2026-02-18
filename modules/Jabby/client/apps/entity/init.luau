local RunService = game:GetService("RunService")

local vide = require(script.Parent.Parent.Parent.vide)
local loop = require(script.Parent.Parent.Parent.modules.loop)
local widget = require(script.widget)

local source = vide.source
local cleanup = vide.cleanup

local overview_entity = {
	class_name = "app" :: "app",
	name = "Entity"
}

type props = {
	host: Player | "server",
	vm: number,
	id: number,
	entity: number,
}

local function generate_random_query_id()
	return math.random(2 ^ 31 - 1)
end

function overview_entity.mount(props: props, destroy: () -> ())

	local keys = source({})
	local changes = source({})
	local enable_live_updates = source(true)
	local apply_changes = source(false)
	local deleting = source(false)
	local inspect_id = generate_random_query_id()

	-- check if the query and columns are properly
	local app_loop = loop (
		"app-client-entity",
		{
			host = props.host,
			vm = props.vm,
			id = props.id,
			inspect_id = inspect_id,
			entity = tonumber(props.entity),

			keys = keys,
			live_updates = enable_live_updates,
			changes = changes,
			apply_changes = apply_changes,
			deleting = deleting
		},

		{i = 1},
		script.systems.obtain_entity_data
	)

	cleanup(
		RunService.Heartbeat:Connect(app_loop)
	)

	return widget {
		host = props.host,
		vm = props.vm,
		id = props.id,
		inspect_id = inspect_id,
		entity = props.entity,

		components = keys,
		live_updates = enable_live_updates,
		changes = changes,
		apply_changes = apply_changes,

		delete = function()
			deleting(true)
		end,

		destroy = destroy
	}

end

return overview_entity