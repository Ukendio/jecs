--[[

Creates a container for a list of elements.

]]

local vide = require(script.Parent.Parent.Parent.Parent.vide)
local container = require(script.Parent.container)

local create = vide.create
local read = vide.read

type can<T> = (() -> T) | T
type layout = {
	
	justifycontent: can<Enum.UIFlexAlignment>?,
	alignitems: can<Enum.ItemLineAlignment>?,
	spacing: can<number | UDim>?,
	wraps: can<boolean>?,

	[number]: Instance
}

local function layout(props: layout)
	return container {

		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		
		create "UIListLayout" {
			Padding = function()
				local spacing: number | UDim? = read(props.spacing)
				
				return if typeof(spacing) == "number" then
					UDim.new(0, spacing)
				elseif typeof(spacing) == "UDim" then
					spacing
				elseif typeof(spacing) == "nil" then
					UDim.new(0, 8)
				else
					error("incorrect spacing type")
			end,

			VerticalFlex = props.justifycontent,
			ItemLineAlignment = props.alignitems,
			Wraps = props.wraps
			
		},

		unpack(props)
	}
	
end

return layout