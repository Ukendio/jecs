local vide = require(script.Parent.Parent.Parent.Parent.vide)
local theme = require(script.Parent.Parent.Parent.util.theme)
local container = require(script.Parent.Parent.util.container)
local padding = require(script.Parent.Parent.util.padding)
local typography = require(script.Parent.typography)

local create = vide.create
local source = vide.source
local changed = vide.changed
local spring = vide.spring

local CHEVRON_DOWN = "rbxassetid://10709790948"
local CHEVRON_UP = "rbxassetid://10709791523"

type can<T> = T | () -> T
type props = {
	text: can<string>,
	expanded: () -> boolean,
	set_expanded: (boolean) -> (),

	[any]: any
}

return function(props: props)

	local gui_state = source(Enum.GuiState.Idle)
	local container_size = source(Vector2.zero)

	return container {
		Name = "Accordion",
		Size = spring(function()
			if props.expanded() == false then return UDim2.new(1, 0, 0, 32) end
			return UDim2.new(1, 0, 0, 40 + container_size().Y)
		end, 0.1),
		ClipsDescendants = true,

		create "ImageButton" {
			Name = "Accordion",
			AutoLocalize = false,
			Size = UDim2.new(1, 0, 0, 32),

			BackgroundColor3 = spring(function()
				return if gui_state() == Enum.GuiState.Press then
					theme.bg[-1]()
				elseif gui_state() == Enum.GuiState.Hover then 
					theme.bg[3]()
				else
					theme.bg[0]()
			end, 0.1),

			padding {x = UDim.new(0, 8)},
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8)
			},

			create "UICorner" {
				CornerRadius = UDim.new(0, 8)
			},

			container {
				Size = UDim2.fromOffset(16, 16),
				create "ImageLabel" {
					Size = UDim2.fromOffset(16, 16),
					BackgroundTransparency = 1,
					AutoLocalize = false,
					Image = CHEVRON_DOWN,
	
					Rotation = spring(function()
						return if props.expanded() then 180 else 0
					end, 0.1)
				},
			},

			typography {
				size = UDim2.fromScale(0, 1),
				text = props.text,
				truncate = Enum.TextTruncate.SplitWord,
				xalignment = Enum.TextXAlignment.Left,

				create "UIFlexItem" {
					FlexMode = Enum.UIFlexMode.Fill
				}
			},

			Activated = function()
				props.set_expanded(not props.expanded())
			end,

			changed("GuiState", gui_state)

		},

		container {
			Name = "Children",

			Position = UDim2.fromOffset(0, 40),
			AutomaticSize = Enum.AutomaticSize.None,
			Size = function()
				return UDim2.new(1, 0, 0, container_size().Y)
			end,
			BackgroundColor3 = theme.bg[3],

			ClipsDescendants = true,

			container {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,

				unpack(props),

				changed("AbsoluteSize", container_size)
			}

		}

	}

end