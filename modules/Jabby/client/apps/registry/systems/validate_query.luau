local Players = game:GetService("Players")

local jecs = require(script.Parent.Parent.Parent.Parent.Parent.jecs)
local vide = require(script.Parent.Parent.Parent.Parent.Parent.vide)
local queue = require(script.Parent.Parent.Parent.Parent.Parent.modules.queue)
local remotes = require(script.Parent.Parent.Parent.Parent.Parent.modules.remotes)

local effect = vide.effect

type Context = {
	host: Player | "server",
	vm: number,
	id: number,

	validate_query: () -> string,

	msg: (string) -> (),
	ok: (boolean) -> (),
	primary_entity: (any?) -> ()

}

return function(context: Context)

	local query_changed = false

	effect(function()
		context.validate_query()

		query_changed = true
	end)

	local n = 0
	local already_validated = false
	local MIN_DELAY_UNTIL_VALIDATE = 0

	local validate_result = queue(remotes.validate_result)

	if context.host == Players.LocalPlayer then
		MIN_DELAY_UNTIL_VALIDATE = 0.3
	elseif context.host == "server" then
		MIN_DELAY_UNTIL_VALIDATE = 0.5
	else
		MIN_DELAY_UNTIL_VALIDATE = 0.5
	end

	return function(dt)
		if query_changed then
			n = 0
			already_validated = false
			query_changed = false
			
			context.ok(false)
			context.msg("")
		end

		for incoming, world, query, terms, ok, msg in validate_result:iter() do
			if incoming.host ~= context.host then continue end
			if incoming.from_vm ~= context.vm then continue end
			if world ~= context.id then continue end
			if query ~= context.validate_query() then continue end

			context.ok(ok)
			context.msg(msg or "")
			context.primary_entity(nil)

			if not terms then continue end
			if #terms.include + #terms.exclude + #terms.with > 1 then continue end
			local first = terms.include[1]

			if first == nil then continue end
			if jecs.IS_PAIR(first) then continue end
			context.primary_entity(terms.include[1])
		end

		n += dt
		if n < MIN_DELAY_UNTIL_VALIDATE then return end
		if already_validated then return end

		if context.validate_query() == "" then 
			context.ok(false)
			context.msg("empty query")
			return
		end
		
		already_validated = true

		remotes.validate_query:fire(
			{
				host = context.host,
				to_vm = context.vm
			},
			context.id,
			context.validate_query()
		)

	end
end