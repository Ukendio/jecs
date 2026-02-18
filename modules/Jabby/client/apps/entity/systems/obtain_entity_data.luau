local vide = require(script.Parent.Parent.Parent.Parent.Parent.vide)
local queue = require(script.Parent.Parent.Parent.Parent.Parent.modules.queue)
local remotes = require(script.Parent.Parent.Parent.Parent.Parent.modules.remotes)

local effect = vide.effect
local cleanup = vide.cleanup
local batch = vide.batch

type Context = {
	host: Player | "server",
	vm: number,
	id: number,
	inspect_id: number,
	entity: number,

	keys: vide.Source<{[string]: string}>,
	changes: vide.Source<{[string]: string}>,
	apply_changes: vide.Source<boolean>,
	live_updates: () -> boolean,
	deleting: () -> boolean,

}

return function(context: Context)

	local inspect_entity_update = queue(remotes.inspect_entity_update)
	
	local current_inspectid = context.inspect_id
	local outgoing = {
		host = context.host,
		to_vm = context.vm,
	}

	remotes.inspect_entity:fire(
		outgoing,	
		context.id,
		context.entity,
		current_inspectid
	)

	local settings_changed = false

	effect(function()
		context.live_updates()
		settings_changed = true
	end)

	cleanup(function()
		remotes.stop_inspect_entity:fire(
			outgoing,
			current_inspectid
		)
	end)

	return function()

		if context.apply_changes() then
			remotes.update_entity:fire(outgoing, current_inspectid, context.changes())
			context.apply_changes(false)
			context.changes({})
		end

		if context.deleting() then
			remotes.delete_entity:fire(outgoing, current_inspectid)
		end

		if settings_changed then
			remotes.update_inspect_settings:fire(
				outgoing,
				current_inspectid,
				{paused = not context.live_updates()}
			)
			settings_changed = false
		end

		batch(function()
			for incoming, inspectid, key, value in inspect_entity_update:iter() do
				if inspectid ~= current_inspectid then continue end
				context.keys()[key] = value
				context.keys(context.keys())
			end
		end)

	end
end