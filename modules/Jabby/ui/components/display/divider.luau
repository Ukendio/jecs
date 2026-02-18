local vide = require(script.Parent.Parent.Parent.Parent.vide)
local theme = require(script.Parent.Parent.Parent.util.theme)

local create = vide.create
local read = vide.read

type can<T> = T | () -> T
type props = {
	thickness: can<number>?,
	position: can<UDim2>?,
}

return function(props: props)
	
	return create "Frame" {
		BackgroundColor3 = theme.bg[-2],
		Position = props.position,
		AutoLocalize = false,
		Size = function()
			return UDim2.new(1, 0, 0, read(props.thickness) or 1)
		end,
	}
end