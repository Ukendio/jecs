local vide = require(script.Parent.Parent.Parent.Parent.vide)
local theme = require(script.Parent.Parent.Parent.util.theme)
local container = require(script.Parent.Parent.util.container)

local create = vide.create
local source = vide.source
local action = vide.action
local effect = vide.effect
local read = vide.read

type can<T> = T | () -> T
type props = {

	position: can<UDim2>?,
	size: can<UDim2>?,
	anchorpoint: can<UDim2>?,

	values: () -> {number},
	max: can<number>?,
	min: can<number>?,

	[number]: Instance
}

return function(props: props)

	local path2d: vide.Source<Path2D> = source()

	effect(function()
		if not path2d() then return end

		local path = path2d()
		local points = table.create(50)
		local total = #props.values()
		local max = read(props.max) or 100
		local min = read(props.min) or 0
		local diff = math.abs(max - min)

		for index, value in props.values() do
			table.insert(
				points,
				Path2DControlPoint.new(
					UDim2.fromScale(
						(index - 1) / (total - 1), 1 - (value - min) / diff
					)
				)
			)
		end

		path:SetControlPoints(points)
	end)

	return container {

		Position = props.position,
		Size = props.size,
		AnchorPoint = props.anchorpoint,
		
		ClipsDescendants = true,

		create "Path2D" {

			Thickness = 2,
			Color3 = theme.acc[3],

			action(path2d)

		},

		unpack(props)

	}

end