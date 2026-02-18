local UserInputService = game:GetService("UserInputService")

local vide = require(script.Parent.Parent.Parent.Parent.vide)

local create = vide.create
local source = vide.source
local cleanup = vide.cleanup
local effect = vide.effect
local action = vide.action
local changed = vide.changed
local untrack = vide.untrack
local read = vide.read

type can<T> = T | () -> T

type snap_area = {
	zindex: can<number>?,
	snapped: (boolean) -> ()
}

type snappable = {
	--- tells the object that you are dragging it
	dragging: () -> boolean,
	--- allows making the widget float by itself without being anchored to anything
	allow_floating: can<boolean>,

	--- callbacks that update the position and size
	snapped: (boolean) -> (),
	position: (UDim2) -> (),
	size: (UDim2) -> ()
}

local function in_bounds(mpos: Vector2, pos: Vector2, size: Vector2)
	return mpos.X >= pos.X and mpos.X <= pos.X + size.X and mpos.Y >= pos.Y and mpos.Y <= pos.Y + size.Y
end

return function()

	local snap_areas = {}
	local mouse_position = source(Vector2.zero)

	local function snap_area(props: snap_area)
		local position = source(Vector2.zero)
		local size = source(Vector2.zero)
		local docked = source(false)

		return create "Frame" {
			Name = "SnapArea",
			AutoLocalize = false,
			Size = UDim2.fromScale(1, 1),

			BackgroundTransparency = 1,
			
			changed("AbsoluteSize", size),
			changed("AbsolutePosition", position),

			action(function(ref)
				snap_areas[ref] = {
					position = position,
					docked = docked,
					size = size,
					zindex = props.zindex or 0
				}

				cleanup(function()
					snap_areas[ref] = nil
				end)
			end)
		}
	end

	local function snappable(props: snappable)
		local snapped_to = source()

		effect(function()
			if props.dragging() == false then return end
			local mpos = mouse_position()

			untrack(function()
				if snapped_to() then snapped_to().docked(false) end

				local snap_to
				
				for _, data in snap_areas do
					if not in_bounds(mpos, data.position(), data.size()) then continue end
					if snap_to and read(data.zindex) <= read(snap_to.zindex) then continue end
					snap_to = data
				end

				if not snap_to and read(props.allow_floating) == false then return end
				if snap_to and snap_to.docked() then return end
				if snap_to then snap_to.docked(true) end
				
				snapped_to(snap_to)
			end)
		end)

		effect(function()
			props.snapped(if snapped_to() then true else false)
		end)

		effect(function()
			if not snapped_to() then return end
			local data = snapped_to()
			local pos = data.position()
			local size = data.size()
			
			props.position(UDim2.fromOffset(pos.X, pos.Y))
			props.size(UDim2.fromOffset(size.X, size.Y))
		end)
	end

	cleanup(UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		mouse_position(Vector2.new(input.Position.X, input.Position.Y))
	end))

	return {
		snap_area = snap_area,
		snappable = snappable
	}

end