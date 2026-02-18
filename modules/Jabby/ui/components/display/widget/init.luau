local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local vide = require(script.Parent.Parent.Parent.Parent.vide)
local theme = require(script.Parent.Parent.Parent.util.theme)
local container = require(script.Parent.Parent.util.container)
local padding = require(script.Parent.Parent.util.padding)
local shadow = require(script.Parent.Parent.util.shadow)
local divider = require(script.Parent.divider)
local snapping = require(script.Parent.snapping)
local borders = require(script.borders)
local topbar = require(script.topbar)

local create = vide.create
local source = vide.source
local cleanup = vide.cleanup
local changed = vide.changed
local reference = vide.action
local spring = vide.spring

type can<T> = T | () -> T
type props = {

	title: can<string>,
	subtitle: can<string>?,
	min_size: Vector2?,
	position: Vector2?,
	size: Vector2?,

	bind_to_close: (() -> ())?,

	[number]: any

}

local HIGHEST_DISPLAY_ORDER = 100000
local RESIZE_RANGE = 6

local docks

vide.mount(function()

	docks = snapping()

	return create "ScreenGui" {
		Name = "docks",
		AutoLocalize = false,
		
		-- create "Frame" {
		-- 	Size = UDim2.new(1, 0, 0, 200),

		-- 	BackgroundTransparency = 1,
	
		-- 	docks.snap_area {}
		-- },
	
		-- create "Frame" {
		-- 	Size = UDim2.new(1, 0, 0, 200),
		-- 	Position = UDim2.fromScale(0, 1),
		-- 	AnchorPoint = Vector2.new(0, 1),
		-- 	BackgroundTransparency = 1,
	
		-- 	docks.snap_area {}
		-- },
	
		create "Frame" {
			Size = UDim2.new(0, 16, 1, 0),
			BackgroundTransparency = 1,
			AutoLocalize = false,
	
			docks.snap_area {}
		},
	}

end, Players.LocalPlayer.PlayerGui)

return function(props: props)
	local min_size = Vector2.new(100, 100):Max(props.min_size or Vector2.zero)
	local position = props.position or Vector2.new(32, 32)
	local base_size = props.size or min_size * 1.5

	local x_size = source(math.max(min_size.X, base_size.X))
	local y_size = source(math.max(min_size.Y, base_size.Y))
	local x_position = source(position.X)
	local y_position = source(position.Y)

	local offset = source(Vector2.zero)
	local dragging = source(false)
	local absolute_position = source(Vector2.zero)
	local absolute_size = source(Vector2.zero)

	local can_resize_top = source(false)
	local can_resize_bottom = source(false)
	local can_resize_right = source(false)
	local can_resize_left = source(false)
	local resizing = source(false)
	local ref = source()
	local display_order = source(HIGHEST_DISPLAY_ORDER + 1)
	HIGHEST_DISPLAY_ORDER += 1

	local mouse_inside = source(false)

	local top: Vector2
	local bottom: Vector2

	cleanup(UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		resizing(false)
		dragging(false)
	end))

	cleanup(UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		if not resizing() then return end

		local mposition = UserInputService:GetMouseLocation()
		local top_inset, bottom_inset = GuiService:GetGuiInset()
		mposition += - top_inset - bottom_inset
		local x, y = mposition.X, mposition.Y

		if can_resize_bottom() then y_size(math.max(y - top.Y, min_size.Y)) end
		if can_resize_right() then x_size(math.max(x - top.X, min_size.X)) end
		if can_resize_top() then
			y_size(math.max(bottom.Y - y, min_size.Y))
			y_position(math.min(y, bottom.Y - min_size.Y))
		end
		if can_resize_left() then
			x_size(math.max(bottom.X - x, min_size.X))
			x_position(math.min(x, bottom.X - min_size.X))
		end
	end))

	cleanup(UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not dragging() then resizing(true) end

		top = absolute_position()
		bottom = absolute_position() + absolute_size()

		local player_gui
		if Players.LocalPlayer and RunService:IsRunning() then
			player_gui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
		elseif RunService:IsStudio() and RunService:IsRunning() then
			player_gui = game:GetService("CoreGui") :: any
		else
			return
		end

		local objects = player_gui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
		if #objects == 0 then return end
		if not objects[1]:IsDescendantOf(ref()) then return end

		display_order(HIGHEST_DISPLAY_ORDER + 1)
		HIGHEST_DISPLAY_ORDER += 1
	end))

	cleanup(UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging() == false then return end
		if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			dragging(false)
			return
		end

		local position = UserInputService:GetMouseLocation()
		-- local top_inset, bottom_inset = GuiService:GetGuiInset()
		-- position += - top_inset - bottom_inset
		x_position(position.X + offset().X)
		y_position(position.Y + offset().Y)
	end))

	local snapped = source(false)
	local snap_size = source(UDim2.new())
	local snap_pos = source(UDim2.new())

	local function radius()
		return if snapped() then UDim.new() else UDim.new(0, 6)
	end
	
	return create "ScreenGui" {
		Name = props.title,
		AutoLocalize = false,
		DisplayOrder = display_order,
		reference(ref),

		create "Frame" {
			AutoLocalize = false,
			Position = function()
				return if snapped() then snap_pos() else UDim2.fromOffset(x_position(), y_position())
			end,

			Size = function()
				return if snapped() then UDim2.fromOffset(x_size() + 6, snap_size().Y.Offset) else UDim2.fromOffset(x_size() + 6, y_size() + 6)
			end,
			
			Active = true,

			BackgroundColor3 = theme.bg[0],

			MouseMoved = function()
				if resizing() then return end

				local mposition = UserInputService:GetMouseLocation()
				local top_inset, bottom_inset = GuiService:GetGuiInset()
				position += - top_inset - bottom_inset
				local x, y = mposition.X, mposition.Y
				x -= absolute_position().X
				y -= absolute_position().Y

				can_resize_top(y < RESIZE_RANGE)
				can_resize_left(x < RESIZE_RANGE)
				can_resize_bottom(y > (absolute_size().Y - RESIZE_RANGE))
				can_resize_right(x > (absolute_size().X - RESIZE_RANGE))
			end,

			MouseEnter = function()
				mouse_inside(true)
			end,

			MouseLeave = function()
				if resizing() then return end
				if RunService:IsRunning() == false then return end

				mouse_inside(false)
			end,

			changed("AbsolutePosition", absolute_position),
			changed("AbsoluteSize", absolute_size),

			create "UICorner" {
				CornerRadius = radius
			},

			shadow {},

			borders {

				resize_range = RESIZE_RANGE,
				min_size = min_size,

				can_resize_top = can_resize_top,
				can_resize_bottom = can_resize_bottom,
				can_resize_left = can_resize_left,
				can_resize_right = can_resize_right,

				resizing = resizing,
			},

			container {
				Size = UDim2.fromScale(1, 1),

				create "UIListLayout" {},

				topbar {
					title = props.title,
					subtitle = props.subtitle,
					dragging = dragging,
					offset = offset,
					bind_to_close = props.bind_to_close,
					radius = radius
				},

				divider {},
				
				container {
					Size = UDim2.fromScale(1, 0),

					padding {
						x = UDim.new(0, 8),
						y = UDim.new(0, 8)
					},

					unpack(props),

					create "UIFlexItem" {
						FlexMode = Enum.UIFlexMode.Grow
					},
				}
			},

			docks.snappable {
				dragging = dragging,

				snapped = snapped,
				position = snap_pos,
				size = snap_size
			}

		},

	}

end