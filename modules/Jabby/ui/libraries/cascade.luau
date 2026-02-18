local vide = require(script.Parent.Parent.Parent.vide)

local action = vide.action
local cleanup = vide.cleanup

--[[

Cascades are applied and passed through an instance.
Use a context if you need to pass this through function scopes.

This is primarily useful for passing down theme information.

]]
local function cascade<T>(default_value: T)

	local self = {}
	local senders: {[Instance]: T} = {}

	local function get_cascaded_value(from: Instance?): T
		while from ~= nil do
			local sender = senders[from]
			if sender ~= nil then
				return sender
			else
				from = from.Parent
			end
		end
		return default_value
	end

	function self.send(value: T)
		return action(function(instance)
			cleanup(function()
				senders[instance] = nil
			end)
			
			senders[instance] = value
		end)
	end

	function self.receive(output_to: (T) -> any)
		return action(function(instance)
			local function recalculate()
				output_to(
					get_cascaded_value(instance.Parent)
				)
			end

			recalculate()

			cleanup(instance.AncestryChanged:Connect(recalculate))
			cleanup(function()
				output_to(default_value)
			end)
		end)
	end

	return self

end

return cascade