local vide = require(script.Parent.Parent.Parent.Parent.Parent.vide)
local queue = require(script.Parent.Parent.Parent.Parent.Parent.modules.queue)
local remotes = require(script.Parent.Parent.Parent.Parent.Parent.modules.remotes)

local effect = vide.effect
local batch = vide.batch
local cleanup = vide.cleanup

type Context = {
	host: Player | "server",
	vm: number,
	id: number,

	columns: vide.Source<{ { any } }>,
	query: () -> string,

	paused: () -> boolean,
	refresh: vide.Source<boolean>,

	total_entities: (number) -> (),

	from: () -> number,
	upto: () -> number,

}

local function generate_random_query_id()
	return math.random(2 ^ 31 - 1)
end

return function(context: Context)

	local query_changed = false
	local page_changed = false

	effect(function()
		if #context.query() > 0 then
			query_changed = true
		end
	end)

	effect(function()
		context.from()
		context.upto()
		page_changed = true
	end)

	local current_query_id = -1
	local query_last_frame = 0
	local update_query_result = queue(remotes.update_query_result)
	local count_updated = queue(remotes.count_total_entities)

	local columns = context.columns
	local outgoing = {
		host = context.host,
		to_vm = context.vm
	}

	cleanup(function()
		remotes.disconnect_query:fire(outgoing, current_query_id)
	end)

	local should_refresh = false
	effect(function()
		if context.refresh() ~= true then return end
		context.refresh(false)
		should_refresh = true
	end)

	local paused_state = context.paused()
	local paused_updated = false
	effect(function()
		paused_updated = true
		paused_state = context.paused()
	end)

	return function()

		if query_changed then
			columns({})
			remotes.disconnect_query:fire(outgoing, current_query_id)
			current_query_id = generate_random_query_id()
			-- print("requesting new query", current_query_id)
			remotes.request_query:fire(outgoing, context.id, current_query_id, context.query())
			remotes.advance_query_page:fire(outgoing, current_query_id, context.from(), context.upto())
			query_last_frame = 0
			query_changed = false

			remotes.pause_query:fire(outgoing, current_query_id, paused_state)
		end

		if page_changed then
			remotes.advance_query_page:fire(outgoing, current_query_id, context.from(), context.upto())
			page_changed = false
		end

		for incoming, query, value in count_updated:iter() do
			if query ~= current_query_id then continue end
			context.total_entities(value)
		end

		if paused_updated then
			remotes.pause_query:fire(outgoing, current_query_id, paused_state)
			paused_updated = false
		end

		if should_refresh then
			remotes.refresh_results:fire(outgoing, current_query_id)
			should_refresh = false
		end

		batch(function()
			for incoming, query, frame, column, row, value in update_query_result:iter() do
				if query ~= current_query_id then continue end
				if frame < query_last_frame - 10 then continue end
				query_last_frame = math.max(query_last_frame, frame)

				if columns()[column] == nil then
					columns()[column] = {}
				end

				columns()[column][row] = value
				columns(columns())
			end
		end)

	end
end