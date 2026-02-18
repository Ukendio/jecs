local vide = require(script.Parent.Parent.Parent.Parent.vide)
local theme = require(script.Parent.Parent.Parent.util.theme)
local container = require(script.Parent.Parent.util.container)

local create = vide.create
local source = vide.source
local action = vide.action
local effect = vide.effect

type can<T> = T | () -> T
type props = {

	position: can<UDim2>?,
	size: can<UDim2>?,
	anchorpoint: can<UDim2>?,

	values: () -> {Path2DControlPoint},

	[number]: Instance

}

return function(props: props)

	local path2d: vide.Source<Path2D> = source()

	effect(function()
		if not path2d() then return end

		local path = path2d()
		path:SetControlPoints(props.values())
	end)

	return container {

		Position = props.position,
		Size = props.size,
		AnchorPoint = props.anchorpoint,

		create "Path2D" {

			Thickness = 2,
			Color3 = theme.acc[3],

			action(path2d)

		},

		unpack(props)

	}

end