local vide = require(script.Parent.Parent.Parent.vide)
local reduced_motion = require(script.Parent.reduced_motion)

local source = vide.source
local spring = vide.spring
local untrack = vide.untrack

type Animation = "move" | ""

return function<T>(s: () -> T)
	local type = typeof(untrack(s))
	local is_movement = false
	local reduce = reduced_motion:consume()

	if type == "UDim" or type == "UDim2" or type == "Vector2" then
		is_movement = true
	end

	local spr = spring(s, 0.1)
	return function()
		if is_movement and reduce then
			return s()
		else
			return spr()
		end
	end
end