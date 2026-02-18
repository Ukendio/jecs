local vide = require(script.Parent.Parent.Parent.Parent.vide)
local anim = require(script.Parent.Parent.Parent.util.anim)
local theme = require(script.Parent.Parent.Parent.util.theme)
local button = require(script.Parent.Parent.interactable.button)
local container = require(script.Parent.Parent.util.container)
local list = require(script.Parent.Parent.util.list)
local padding = require(script.Parent.Parent.util.padding)
local rounded_frame = require(script.Parent.Parent.util.rounded_frame)
local divider = require(script.Parent.divider)
local typography = require(script.Parent.typography)

local create = vide.create
local source = vide.source
local changed = vide.changed
local indexes = vide.indexes
local untrack = vide.untrack
local cleanup = vide.cleanup

type can<T> = T | () -> T
type props = {
	labels: () -> {
		{
			title: string,
			ui: () -> Instance | {Instance}
		}
	}
}

return function(props: props)

	local selected = source(1)

	return list {
		justifycontent = Enum.UIFlexAlignment.Fill,
		spacing = UDim.new(),

		create "Frame" {
			Size = UDim2.new(1, 0, 0, 32),
			AutoLocalize = false,
			BackgroundColor3 = theme.bg[3],

			divider {
				position = UDim2.fromScale(0, 1),
			},

			container {
				create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal
				},
	
				indexes(props.labels, function(value, key)
					local guistate = source(Enum.GuiState.Idle)
	
					return rounded_frame {
						name = key,
						size = UDim2.fromOffset(50, 30),
						automaticsize = Enum.AutomaticSize.X,
						topleft = UDim.new(0, 4),
						topright = UDim.new(0, 4),
	
						color = function()
							return if selected() == key then theme.bg[0]()
								elseif guistate() == Enum.GuiState.Idle then theme.bg[3]()
								else theme.bg[1]()
						end,
	
						create "TextButton" {
							Size = UDim2.fromScale(1, 1),
							AutoLocalize = false,
							BackgroundTransparency = 1,
							
							Activated = function()
								selected(key)
							end,
					
							typography {
					
								position = UDim2.fromScale(0.5, 0.5),
								anchorpoint = Vector2.new(0.5, 0.5),
					
								text = function()
									return value().title
								end,
								
								textsize = 16
							},
					
					
							padding {
								x = UDim.new(0, 24),
								y = UDim.new(0, 2)
							},
					
							changed("GuiState", guistate)
						}
					}
				end),
			},

			ZIndex = 100,

		},
		
		create "Frame" {
			Size = UDim2.new(1, 0, 1, 0),
			AutoLocalize = false,

			BackgroundColor3 = theme.bg[0],

			function()
				return untrack(props.labels()[selected()].ui)
			end

		},

	}

end