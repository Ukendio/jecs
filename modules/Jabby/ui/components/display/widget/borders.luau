local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local vide = require(script.Parent.Parent.Parent.Parent.Parent.vide)
local theme = require(script.Parent.Parent.Parent.Parent.util.theme)
local container = require(script.Parent.Parent.Parent.util.container)

local create = vide.create
local source = vide.source
local spring = vide.spring
local changed = vide.changed
local cleanup = vide.cleanup

type Source<T> = vide.Source<T>
type props = {

	resize_range: number,
	min_size: Vector2,

	can_resize_left: Source<boolean>,
	can_resize_right: Source<boolean>,
	can_resize_bottom: Source<boolean>,
	can_resize_top: Source<boolean>,

	resizing: () -> boolean,
}

local function xpos(s: () -> number)
	return function()
		return Vector2.new(s(), 0)
	end
end

local function ypos(s: () -> number)
	return function()
		return Vector2.new(0, s())
	end
end

return function(props: props)
	local RESIZE_RANGE = props.resize_range
	local MIN_SIZE = props.min_size

	local can_resize_left = props.can_resize_left
	local can_resize_right = props.can_resize_right
	local can_resize_bottom = props.can_resize_bottom
	local can_resize_top = props.can_resize_top
	local resizing = props.resizing

	local absolute_size = source(Vector2.new(1, 1))
	local absolute_position = source(Vector2.zero)

	local thickness = 4
	local border_selected = theme.acc[8]
	local gradient = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.75, 1),
		NumberSequenceKeypoint.new(1, 1),
	})

	local x = source(0)
	local y = source(0)

	cleanup(RunService.Heartbeat:Connect(function()
		local mposition = UserInputService:GetMouseLocation()
		local top_inset, bottom_inset = GuiService:GetGuiInset()
		mposition += - top_inset - bottom_inset

		if MIN_SIZE.X ~= absolute_size().X or not resizing() then x(mposition.X) end
		if MIN_SIZE.Y ~= absolute_size().Y or not resizing() then y(mposition.Y) end
	end))

	cleanup(RunService.RenderStepped:Connect(function()
		local mposition = UserInputService:GetMouseLocation()
		local top_inset, bottom_inset = GuiService:GetGuiInset()
		mposition += - top_inset - bottom_inset
		local x, y = mposition.X, mposition.Y

		if resizing() then return end

		local left = absolute_position().X
		local top = absolute_position().Y
		local right = left + absolute_size().X
		local bottom = top + absolute_size().Y

		local topleft = absolute_position() - Vector2.new(RESIZE_RANGE, RESIZE_RANGE)
		local bottomright = absolute_position() + absolute_size() + Vector2.new(RESIZE_RANGE, RESIZE_RANGE)

		-- perform AABB to check if the cursor is in range
		local within_bounds = x > topleft.X and y > topleft.Y and x < bottomright.X and y < bottomright.Y

		can_resize_top(y > top - RESIZE_RANGE and y < top and within_bounds)
		can_resize_left(x < left + RESIZE_RANGE and x > left - RESIZE_RANGE and within_bounds)
		can_resize_bottom(y < bottom + RESIZE_RANGE and y > bottom - RESIZE_RANGE and within_bounds)
		can_resize_right(x < right + RESIZE_RANGE and x > right - RESIZE_RANGE and within_bounds)
	end))

	return {

		changed("AbsoluteSize", function(value: Vector2)
			if value.Magnitude == 0 then return end
			absolute_size(value)
		end),
		changed("AbsolutePosition", absolute_position),

		container {

			Name = "Left",

			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(0, thickness, 1, thickness * 2),
			AnchorPoint = Vector2.new(1, 0.5),

			BackgroundColor3 = border_selected,

			BackgroundTransparency = spring(function()
				return can_resize_left() and 0 or 1
			end, 0.2),

			ZIndex = 1000,

			create "UIGradient" {

				Rotation = 90,

				Transparency = gradient,
				Offset = ypos(spring(function()
					return (y() - absolute_position().Y - absolute_size().Y / 2) / absolute_size().Y
				end, 0.1)),
			},

			create "UICorner" {
				CornerRadius = UDim.new(0, 4)
			},
		},

		container {

			Name = "Right",

			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.new(0, thickness, 1, thickness * 2),
			AnchorPoint = Vector2.new(0, 0.5),

			BackgroundColor3 = border_selected,

			BackgroundTransparency = spring(function()
				return can_resize_right() and 0 or 1
			end, 0.2),

			ZIndex = 1000,

			create "UIGradient" {

				Rotation = 90,

				Transparency = gradient,
				Offset = ypos(spring(function()
					return (y() - absolute_position().Y - absolute_size().Y / 2) / absolute_size().Y
				end, 0.1)),
			},

			create "UICorner" {
				CornerRadius = UDim.new(0, 4)
			},
		},

		container {

			Name = "Bottom",

			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, thickness * 2, 0, thickness),
			AnchorPoint = Vector2.new(0.5, 0),

			BackgroundColor3 = border_selected,

			BackgroundTransparency = spring(function()
				return can_resize_bottom() and 0 or 1
			end, 0.2),

			ZIndex = 1000,

			create "UIGradient" {

				Transparency = gradient,
				Offset = xpos(spring(function()
					return (x() - absolute_position().X - absolute_size().X / 2) / absolute_size().X
				end, 0.1)),
			},

			create "UICorner" {
				CornerRadius = UDim.new(0, 4)
			},
		},

		container {

			Name = "Top",

			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(1, thickness * 2, 0, thickness),
			AnchorPoint = Vector2.new(0.5, 1),

			BackgroundColor3 = border_selected,

			BackgroundTransparency = spring(function()
				return can_resize_top() and 0 or 1
			end, 0.2),

			ZIndex = 1000,

			create "UIGradient" {

				Transparency = gradient,
				Offset = xpos(spring(function()
					return (x() - absolute_position().X - absolute_size().X / 2) / absolute_size().X
				end, 0.1)),
			},

			create "UICorner" {
				CornerRadius = UDim.new(0, 4)
			},
		},
	} :: { any }
end