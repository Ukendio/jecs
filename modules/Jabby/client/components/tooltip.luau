local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ui = require(script.Parent.Parent.Parent.ui)
local vide = require(script.Parent.Parent.Parent.vide)

local create = vide.create
local source = vide.source
local cleanup = vide.cleanup

type props = {
	visible: boolean | () -> boolean,
	transparency: number? | () -> number,
	[number]: any
}

return function(props: props)

	local mouse_location = source(Vector2.zero)

	cleanup(RunService.PreRender:Connect(function()
		mouse_location(UserInputService:GetMouseLocation())
	end))

	return create "ScreenGui" {
		Name = "Mouse Hover",
		IgnoreGuiInset = true,
		DisplayOrder = 1e9,
		Enabled = props.visible,

		create "Frame" {
			Position = function()
				return UDim2.fromOffset(
					mouse_location().X + 24,
					mouse_location().Y + 24
				)
			end,
			Size = UDim2.fromOffset(400, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = ui.theme.bg[0],
			BackgroundTransparency = props.transparency or 0.5,

			ui.padding {},

			create "UICorner" {
				CornerRadius = UDim.new(0, 8)
			},

			create "UIStroke" {
				Color = ui.theme.bg[-10],
				Thickness = 2,
				Transparency = 0.8
			},

			unpack(props)
		}

	}

end