--[[

Fast and easy to use padding utility to make controlling padding quick and simple.

]]

local vide = require(script.Parent.Parent.Parent.Parent.vide)

local create = vide.create

type can<T> = T | () -> T
type padding = {
	padding: can<UDim>?,
	x: can<UDim>?,
	y: can<UDim>?,
	left: can<UDim>?,
	right: can<UDim>?,
	top: can<UDim>?,
	bottom: can<UDim>?
}

local function padding(props: padding)
	
	local padding = props.padding or UDim.new(0, 8)
	local x = props.x or padding
	local y = props.y or padding
	local left = props.left or x
	local right = props.right or x
	local top = props.top or y
	local bottom = props.bottom or y

	return create "UIPadding" {
		PaddingLeft = left,
		PaddingRight = right,
		PaddingTop = top,
		PaddingBottom = bottom,
	}
	
end

return padding