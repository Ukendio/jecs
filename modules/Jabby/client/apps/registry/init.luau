local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local vide = require(script.Parent.Parent.Parent.vide)
local loop = require(script.Parent.Parent.Parent.modules.loop)
local spawn_app = require(script.Parent.Parent.spawn_app)
local entity_widget = require(script.Parent.entity)
local widget = require(script.widget)

local source = vide.source
local effect = vide.effect
local cleanup = vide.cleanup

local overview_query = {
	class_name = "app" :: "app",
	name = "Query"
}

type props = {
	host: Player | "server",
	vm: number,
	id: number
}

function overview_query.mount(props: props, destroy: () -> ())

	-- the entity id
	local current_entity = source(nil)
	-- enables picking
	local enable_pick = source(false)
	-- the entity data as a string
	local entity_hovering_over = source()
	-- the part the player is hovering over
	local hovering_over = source()

	local validate_query = source("")
	local ok = source(false)
	local msg = source("")

	local query = source("")
	local primary_entity = source()
	local columns = source({})
	local from = source(1)
	local upto = source(25)
	local total_entities = source(0)

	local paused = source(false)
	local refresh = source(false)

	-- check if the query and columns are properly
	local app_loop = loop (
		"app-client-registry",
		{
			host = props.host,
			vm = props.vm,
			id = props.id,

			enable_pick = enable_pick,
			entity_hovering_over = entity_hovering_over,
			hovering_over = hovering_over,
			set_entity = current_entity,

			columns = columns,
			query = query,
			primary_entity = primary_entity,
			paused = paused,
			refresh = refresh,

			total_entities = total_entities,

			from = from,
			upto = upto,

			validate_query = validate_query,
			ok = ok,
			msg = msg
		},

		{i = 1},
		script.systems.validate_query,
		script.systems.obtain_query_data,
		script.systems.send_workspace_entity,
		script.systems.highlight_workspace_entity
	)

	cleanup(RunService.Heartbeat:Connect(app_loop))

	local function open_entity_widget(_, state: Enum.UserInputState)
		local entity = current_entity()

		if state ~= Enum.UserInputState.Begin then return end
		if entity == nil then return end

		enable_pick(false)
		entity_hovering_over(nil)
		hovering_over(nil)

		spawn_app.spawn_app(entity_widget, {
			host = props.host,
			vm = props.vm,
			id = props.id,
			entity = entity
		})
	end

	effect(function()
		local picking = enable_pick()
		local key = `select entity:{props.host} {props.vm} {props.id}`

		if picking then
			ContextActionService:BindAction(key, open_entity_widget, false, Enum.UserInputType.MouseButton1)
		end

		cleanup(function()
			ContextActionService:UnbindAction(key)
		end)

	end)
	
	return widget {
		host = props.host,
		vm = props.vm,
		id = props.id,

		validate_query = validate_query,

		update_system_query = query,
		current_query = query,
		total_rows_per_page = source(25),
		set_rows_per_page = source(25),

		primary_entity = primary_entity,

		from = from,
		upto = upto,
		total_entities = total_entities,
		paused = paused,
		refresh = refresh,

		enable_pick = enable_pick,
		entity_hovering_over = entity_hovering_over,
		hovering_over = hovering_over,

		ok = ok,
		msg = msg,

		columns = columns,
		
		destroy = destroy
	}

end

return overview_query