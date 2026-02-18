local vide = require(script.Parent.Parent.Parent.Parent.vide)
local theme = require(script.Parent.Parent.Parent.util.theme)
local scroll_frame = require(script.Parent.Parent.display.scroll_frame)
local container = require(script.Parent.Parent.util.container)
local list = require(script.Parent.Parent.util.list)
local padding = require(script.Parent.Parent.util.padding)
local portal = require(script.Parent.Parent.util.portal)
local button = require(script.Parent.button)

local create = vide.create
local source = vide.source
local changed = vide.changed
local indexes = vide.indexes
local spring = vide.spring
local read = vide.read

local MAX_SIZE = 100

type can<T> = T | () -> T
type dropdown = {
	size: can<UDim2>?,
	position: can<UDim2>?,
	anchorpoint: can<Vector2>?,

	selected: can<number>,
	update_selected: (() -> number)?,

	options: can<{string}>
}

local function dropdown(props: dropdown)
	
	local selected = props.selected
	local update_selected = props.update_selected or function() end
	local options = props.options

	local enabled = source(false)
	local absolute_size = source(Vector2.zero)

	local size = spring(function()
		if not enabled() then return UDim2.fromScale(1, 0) end
		return UDim2.new(1, 0, 0, math.min(MAX_SIZE, absolute_size().Y))
	end, 0.1)

	return button {

		size = props.size or UDim2.fromOffset(200, 32),
		position = props.position or UDim2.fromScale(0.5, 0.5),
		anchorpoint = props.anchorpoint or Vector2.new(0.5, 0.5),

		xalignment = Enum.TextXAlignment.Left,

		text = function()
			return read(options)[read(selected)]
		end,

		activated = function()
			enabled(not enabled())
		end,
		
		create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
		},
		
		container {

			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 18, 0, 16),

			LayoutOrder = -1,

			create "ImageLabel" {

				Name = "arrow",
				AutoLocalize = false,

				Size = UDim2.new(0, 8, 0, 4),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = spring(function()
					return if enabled() then -180 else 0
				end, 0.1),

				BackgroundTransparency = 1,

				BackgroundColor3 = theme.fg_on_bg_high[3],

				Image = "rbxassetid://7260137654",
				ImageColor3 = theme.fg_on_bg_low[3],
				ScaleType = Enum.ScaleType.Stretch

			}

		},

		portal {
			inherit_layout = true,
			
			container {
				Position = UDim2.new(0, 1, 1, 4),
				Size = size,

				BackgroundTransparency = 0,
				BackgroundColor3 = theme.bg[3],

				ClipsDescendants = true,

				Visible = function()
					return size().Y.Offset > 1
				end,

				padding {
					padding = UDim.new(0, 2)
				},

				scroll_frame {
					Size = UDim2.fromScale(1, 1),
					ScrollBarThickness = 4,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,

					list {
						spacing = UDim.new(0, 1),

						changed("AbsoluteSize", absolute_size),

						indexes(function()
							return read(options)
						end, function(value, key)
							return button {
								size = UDim2.new(1, 0, 0, 30),
								text = value,
								stroke = false,

								activated = function()
									enabled(false)
									update_selected(key)
								end,

								create "UIListLayout" {
									FillDirection = Enum.FillDirection.Horizontal,
									VerticalAlignment = Enum.VerticalAlignment.Center,
									Padding = UDim.new(0, 8),
								},
							}
						end)
					}
				},

				create "UIStroke" {
					Color = theme.bg[-3]
				},

				create "UICorner" {
					CornerRadius = UDim.new(0, 3)
				}
			}
		}

	}
	
end

return dropdown