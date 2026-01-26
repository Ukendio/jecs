--!native
--!optimize 2
--!strict
local Spring_Vector3 = require("./vector3")

export type Spring = {
	type: "Color3",
	d: number,
	f: number,
	g: Vector3,
	p: Vector3,
	v: Vector3
}

local function create(d: number, f: number, origo: Color3, goal: Color3): Spring
	return {
		type = "Color3",
		d = d,
		f = f,
		g = Vector3.new(),
		p = Vector3.new(),
		v = Vector3.new(),
	}
end

local function inverseGammaCorrectD65(c)
	return c < 0.0404482362771076 and c/12.92 or 0.87941546140213*(c + 0.055)^2.4
end

local function gammaCorrectD65(c)
	return c < 3.1306684425e-3 and 12.92*c or 1.055*c^(1/2.4) - 0.055
end

local function rgbToLuv(value: Vector3): Color3
	-- convert RGB to a variant of cieluv space
	local r, g, b = value.X, value.Y, value.Z

	-- D65 sRGB inverse gamma correction
	r = inverseGammaCorrectD65(r)
	g = inverseGammaCorrectD65(g)
	b = inverseGammaCorrectD65(b)

	-- sRGB -> xyz
	local x = 0.9257063972951867*r - 0.8333736323779866*g - 0.09209820666085898*b
	local y = 0.2125862307855956*r + 0.71517030370341085*g + 0.0722004986433362*b
	local z = 3.6590806972265883*r + 11.4426895800574232*g + 4.1149915024264843*b

	-- xyz -> scaled cieluv
	local l = y > 0.008856451679035631 and 116*y^(1/3) - 16 or 903.296296296296*y

	local u, v
	if z > 1e-14 then
		u = l*x/z
		v = l*(9*y/z - 0.46832)
	else
		u = -0.19783*l
		v = -0.46832*l
	end

	return Color3.new(l,u,v)
end
local function luvToRgb(value: Vector3): Color3
	-- convert back from modified cieluv to rgb space
	local l = value.X
	if l < 0.0197955 then
		return Color3.new(0, 0, 0)
	end
	local u = value.Y/l + 0.19783
	local v = value.Z/l + 0.46832

	-- cieluv -> xyz
	local y = (l + 16)/116
	y = y > 0.206896551724137931 and y*y*y or 0.12841854934601665*y - 0.01771290335807126
	local x = y*u/v
	local z = y*((3 - 0.75*u)/v - 5)

	-- xyz -> D65 sRGB
	local r =  7.2914074*x - 1.5372080*y - 0.4986286*z
	local g = -2.1800940*x + 1.8757561*y + 0.0415175*z
	local b =  0.1253477*x - 0.2040211*y + 1.0569959*z

	-- clamp minimum sRGB component
	if r < 0 and r < g and r < b then
		r, g, b = 0, g - r, b - r
	elseif g < 0 and g < b then
		r, g, b = r - g, 0, b - g
	elseif b < 0 then
		r, g, b = r - b, g - b, 0
	end

	-- gamma correction from D65
	-- clamp to avoid undesirable overflow wrapping behavior on certain properties (e.g. BasePart.Color)
	return Color3.new(
		math.min(gammaCorrectD65(r), 1),
		math.min(gammaCorrectD65(g), 1),
		math.min(gammaCorrectD65(b), 1)
	)
end

local function step(spring: Spring, dt: number): Color3
	Spring_Vector3.step((spring::any), dt)
	return rgbToLuv(spring.g)
end

return {
	create = create,
	step = step,
	can_sleep = Spring_Vector3.can_sleep,
	rgbToLuv = rgbToLuv
}
