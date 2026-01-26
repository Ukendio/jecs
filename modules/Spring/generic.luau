local cframe = require("./cframe")
local color3 = require("./color3")
local number = require("./number")
local vector2 = require("./vector2")
local vector3 = require("./vector3")

export type Spring =
	| cframe.Spring
	| color3.Spring
	| number.Spring
	| vector2.Spring
	| vector3.Spring

local function exhaustive(x: never)
	error(x)
end


local function step(spring: Spring, dt: number)
	if spring.type == "CFrame" then
		cframe.step(spring, dt)
	elseif spring.type == "Color3" then
		color3.step(spring, dt)
	elseif spring.type == "Vector2" then
		vector2.step(spring, dt)
	elseif spring.type == "Vector3" then
		vector3.step(spring, dt)
	elseif spring.type == "number" then
		number.step(spring, dt)
	else
		exhaustive(spring.type)
	end
end


local function can_sleep(spring: Spring)
	if spring.type == "CFrame" then
		cframe.can_sleep(spring)
	elseif spring.type == "Color3" then
		color3.can_sleep((spring::any)::vector3.Spring)
	elseif spring.type == "Vector2" then
		vector2.can_sleep(spring)
	elseif spring.type == "Vector3" then
		vector3.can_sleep(spring)
	elseif spring.type == "number" then
		number.can_sleep(spring)
	else
		exhaustive(spring.type)
	end
end

return {
	step = step,
	can_sleep = can_sleep,
}
