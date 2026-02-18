
local vide = require(script.Parent.Parent.Parent.Parent.Parent.vide)
local theme = require(script.Parent.Parent.Parent.Parent.util.theme)
local list = require(script.Parent.Parent.Parent.util.list)
local padding = require(script.Parent.Parent.Parent.util.padding)
local rounded_frame = require(script.Parent.Parent.Parent.util.rounded_frame)
local typography = require(script.Parent.Parent.typography)

local create = vide.create
local source = vide.source
local changed = vide.changed
local spring = vide.spring
local show = vide.show

type Source<T> = vide.Source<T>
type props = {

	title: (string | () -> string)?,
	subtitle: (string | () -> string)?,
	bind_to_close: (() -> ())?,

	radius: () -> UDim,

	dragging: Source<boolean>,
	offset: (new: Vector2) -> (),

	[any]: any,
}

return function(props: props)
	local bind_to_close = props.bind_to_close
	local dragging = props.dragging
	local offset = props.offset

	local closeable = not not bind_to_close

	local absolute_position = source(Vector2.zero)

	local gui_state = source(Enum.GuiState.Idle)

	return rounded_frame {

		name = "Topbar",
	
		size = UDim2.new(1, 0, 0, 48),
		color = theme.bg[3],

		topleft = props.radius,
		topright = props.radius,

		create "ImageButton" {
			Size = UDim2.fromScale(1, 1),
			AutoLocalize = false,
			BackgroundTransparency = 1,
			ZIndex = 1000,
	
			changed("AbsolutePosition", absolute_position),
	
			MouseButton1Down = function(x, y)
				offset(absolute_position() - Vector2.new(x, y))
				dragging(true)
			end,
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
			},
	
			padding {
				x = UDim.new(0, 16)
			},
	
			list {
				spacing = UDim.new(),

				typography {
					size = UDim2.fromScale(1, 0),
					text = props.title,
					
					xalignment = Enum.TextXAlignment.Left,
					truncate = Enum.TextTruncate.SplitWord,
					textsize = 20,
					header = true,
				},

				show(function()
					return props.subtitle ~= nil
				end, function()
					return typography {
						size = UDim2.fromScale(1, 0),
						text = props.subtitle,
						bold = true,
						
						xalignment = Enum.TextXAlignment.Left,
						truncate = Enum.TextTruncate.SplitWord,
	
						textsize = 16,
					}
				end)

			},

			show(source(closeable), function()
				return create "ImageButton" {

					Size = UDim2.fromOffset(32, 32),
	
					BackgroundColor3 = spring(function()
						return if gui_state() == Enum.GuiState.Hover then
							theme.bg[5]()
						elseif gui_state() == Enum.GuiState.Press then
							theme.bg[0]()
						else
							theme.bg[3]()
					end, 0.1),
	
					changed("GuiState", gui_state),
	
					Activated = props.bind_to_close,
	
					create "UICorner" {
						CornerRadius = UDim.new(1, 0)
					},
	
					create "ImageLabel" {
						Size = UDim2.fromOffset(24, 24),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						AutoLocalize = false,
	
						BackgroundTransparency = 1,

						ImageColor3 = theme.fg_on_bg_high[3],
	
						Image = "rbxassetid://10747384394",
	
					},
	
					create "UIFlexItem" {
						FlexMode = Enum.UIFlexMode.Custom,
						ShrinkRatio = 0
					}
	
				}
			end)
	
		}

	}
end