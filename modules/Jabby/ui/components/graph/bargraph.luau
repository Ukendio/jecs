local vide = require(script.Parent.Parent.Parent.Parent.vide)
local theme = require(script.Parent.Parent.Parent.util.theme)
local container = require(script.Parent.Parent.util.container)

local create = vide.create
local indexes = vide.indexes
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

	local max = props.max or function()
		return math.max(unpack(props.values()))
	end

	local function total()
		return #props.values()
	end

	return container {

		Position = props.position,
		Size = props.size,
		AnchorPoint = props.anchorpoint,

		ClipsDescendants = true,

		indexes(props.values, function(value, index)
			
			return create "Frame" {
				AutoLocalize = false,

				Position = function()
					return UDim2.fromScale((index - 1) / total(), 1)
				end,
				Size = function()
					return UDim2.fromScale(
						1/total(),
						value() / read(max)
					)
				end,
				AnchorPoint = Vector2.new(0, 1),

				create "UIGradient" {
					Color = function()
						return ColorSequence.new(
							theme.acc[10](),
							theme.acc[-3]()
						)
					end,

					Rotation = 90
				}

			}

		end),

		unpack(props)

	}

end