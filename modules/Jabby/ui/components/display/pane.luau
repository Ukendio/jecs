local vide = require(script.Parent.Parent.Parent.Parent.vide)
local theme = require(script.Parent.Parent.Parent.util.theme)
local list = require(script.Parent.Parent.util.list)
local padding = require(script.Parent.Parent.util.padding)
local background = require(script.Parent.background)
local typography = require(script.Parent.typography)

local create = vide.create
local read = vide.read
local show = vide.show

type can<T> = T | () -> T
type props = {

	size: can<UDim2>?,
	position: can<UDim2>?,
	anchorpoint: can<UDim2>?,
	layoutorder: can<number>?,
	automaticsize: can<Enum.AutomaticSize>?,

	name: can<string>?,

	[number]: any

}

return function(props: props)

	return create "Frame" {
		Name = props.name,
		Size = props.size or UDim2.fromScale(1, 0),
		Position = props.position,
		AnchorPoint = props.anchorpoint,
		LayoutOrder = props.layoutorder,
		AutomaticSize = props.automaticsize or Enum.AutomaticSize.Y,
		BackgroundColor3 = theme.bg[0],
		AutoLocalize = false,

		create "UICorner" {
			CornerRadius = UDim.new(0, 8)
		},
		create "UIStroke" {
			Color = theme.bg[-3]
		},
		show(function()
			return if read(props.name) then #read(props.name) > 0 else false
		end, function()
			return background {
				size = UDim2.new(),
				position = UDim2.fromOffset(4, -16),
				automaticsize = Enum.AutomaticSize.XY,

				typography {
					text = props.name,
					disabled = true,

					textsize = 14
				},

				padding {x = UDim.new(0, 2), y = UDim.new()}
			}
		end),

		padding {},
		list {
			unpack(props)
		}

	}
end