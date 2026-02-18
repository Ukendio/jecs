local ui = require(script.Parent.Parent.Parent.Parent.ui)
local vide = require(script.Parent.Parent.Parent.Parent.vide)

local create = vide.create
local show = vide.show

type props = {
	components: () -> {[string]: string},
	changes: vide.Source<{[string]: string}>,
	editing: vide.Source<false | string>,
	text: vide.Source<string>
}

return function(props: props)

	local editing = props.editing
	local text = props.text
	local changes = props.changes

	return create "Folder" {
		Name = "Text Editor",

		show(function()
			return editing()
		end, function()
			return create "Frame" {
				ZIndex = 1000,
				Size = UDim2.new(1,16, 1, 16),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),

				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.5,

				Active = true,

				create "UIListLayout" {
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					VerticalFlex = Enum.UIFlexAlignment.SpaceEvenly,
					Padding = UDim.new(0, 8)
				},

				ui.padding {
					padding = UDim.new(0, 32)
				},

				ui.typography {
					text = function()
						return `Editing {editing()}`
					end
				},

				create "Frame" {
					Size = UDim2.fromScale(1, 0),
					
					create "UIFlexItem" {
						FlexMode = Enum.UIFlexMode.Fill
					},
					
					BackgroundTransparency = 1,

					ui.textfield {
						size = UDim2.fromScale(1, 1),
						position = UDim2.fromScale(0.5, 0.5),
						anchorpoint = Vector2.new(0.5, 0.5),

						multiline = true,
						code = true,

						text = text,
						oninput = text,
					},	
				},

				create "Frame" {
					Size = UDim2.new(1, 0, 0, 30),
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.Y,

					create "UIListLayout" {
						HorizontalFlex = Enum.UIFlexAlignment.Fill,
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 8)
					},
					
					ui.button {
						size = UDim2.fromOffset(150, 30),
						text = "Save Changes",
						activated = function()
							local key = editing()
							changes()[key] = text()

							editing(false)
							changes(changes())

							if props.components()[key] ~= nil then return end
							props.components()[key] = text()
						end,
						accent = true
					},
					
					ui.button {
						size = UDim2.fromOffset(150, 30),
						text = "Cancel Changes",
						activated = function()
							editing(false)
						end
					},
				}

				
			}
		end)

	}

end