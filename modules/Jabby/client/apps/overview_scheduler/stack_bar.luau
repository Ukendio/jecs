local vide = require(script.Parent.Parent.Parent.Parent.vide)

local create = vide.create
local indexes = vide.indexes
local derive = vide.derive

type stack_bar = {
	values: () -> {{value: number, color: Color3}},
	selected: (number) -> ()
}

return function(props: stack_bar)

	local total = derive(function()
		local total = 0
		for _, value in props.values() do
			total += value.value
		end
		return total
	end)

	return create "Frame" {
		Name = "Graph",
		Size = UDim2.new(1, 0, 0, 32),

		indexes(props.values, function(value, index)
			return create "Frame" {

				Size = function()
					return UDim2.fromScale(value().value / total(), 1)
				end,

				BackgroundColor3 = function() return value().color end,

				MouseEnter = function()
					props.selected(index)
				end,
			}
		end),

		create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
		},
	}

end