local vide = require(script.Parent.Parent.Parent.Parent.vide)
local theme = require(script.Parent.Parent.Parent.util.theme)

local create = vide.create

type props = vide.vScrollingFrame

return function(props: props)

	return create "ScrollingFrame" {
		AutoLocalize = false,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = theme.fg_on_bg_low[0],
		CanvasSize = UDim2.new(),
		
		BackgroundTransparency = 1,

		props

	}
	
end