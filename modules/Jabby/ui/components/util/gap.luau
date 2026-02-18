local vide = require(script.Parent.Parent.Parent.Parent.vide)
local container = require(script.Parent.container)

local read = vide.read

type can<T> = T | () -> T
type props = {

	gap: can<number>,
	direction: can<"x" | "y">?,

}

return function(props: props)

	local function direction()
		return read(props.direction) or "x"
	end

	return container {

		Size = function()
			return if direction() == "x" then
				UDim2.new(0, read(props.gap), 1, 0)
			else
				UDim2.new(1, 0, 0, read(props.gap))
		end

	}

end