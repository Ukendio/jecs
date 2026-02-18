local ui = require(script.Parent.Parent.Parent.Parent.ui)
local vide = require(script.Parent.Parent.Parent.Parent.vide)
local query_parser = require(script.Parent.Parent.Parent.Parent.server.query_parser)

local create = vide.create
local source = vide.source
local show = vide.show

type props = {
	changes: vide.Source<{[string]: string}>,
	editing: vide.Source<false | string>,
	adding: vide.Source<false | string>,
	text: vide.Source<string>
}

return function(props: props)

	local component_edit_text = source("")
	local adding = props.adding
	local editing = props.editing
	local text = props.text

	return create "Folder" {
		Name = "Add Component",

		show(adding, function()
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
					Padding = UDim.new(0, 8)
				},

				ui.padding {
					padding = UDim.new(0, 32)
				},

				ui.textfield {
					size = UDim2.fromOffset(200, 30),

					placeholder = "Entity",

					oninput = component_edit_text,
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
						text = "Edit",
						activated = function()
							adding(false)
							editing(component_edit_text())
						end,
						disabled = function()
							local ok, node = pcall(query_parser, component_edit_text())

							if not ok then return true end
							if not node[1] then return true end
							if node[2] then return true end
							local n = node[1]
							if n.type == "Relationship" then
								if n.left.type == "Wildcard" then return true end
								if n.right.type == "Wildcard" then return true end
							end

							return false
						end,
						accent = true
					},
					
					ui.button {
						size = UDim2.fromOffset(150, 30),
						text = "Cancel",
						activated = function()
							adding(false)
						end
					},
				}

				
			}
		end)

	}

end