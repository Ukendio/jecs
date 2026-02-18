--!nolint
--!strict
-- Oklab C implementation provided by Björn Ottosson:
--     https://bottosson.github.io/posts/gamutclipping/
-- Luau port and Roblox/Lch extensions by Elttob:
--     https://elttob.uk/
-- Licensed under MIT

local TAU = 2 * math.pi

local function cbrt(x: number)
	return math.sign(x) * math.abs(x) ^ (1/3)
end

local Oklab = {}

function Oklab.linear_srgb_to_oklab(
	c: Vector3
): Vector3
	local l = 0.4122214708 * c.X + 0.5363325363 * c.Y + 0.0514459929 * c.Z
	local m = 0.2119034982 * c.X + 0.6806995451 * c.Y + 0.1073969566 * c.Z
	local s = 0.0883024619 * c.X + 0.2817188376 * c.Y + 0.6299787005 * c.Z
	
	local l_ = cbrt(l)
	local m_ = cbrt(m)
	local s_ = cbrt(s)

	return Vector3.new(
		0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
		1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
		0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
	)
end

function Oklab.oklab_to_linear_srgb(
	c: Vector3
): Vector3
	local l_ = c.X + 0.3963377774 * c.Y + 0.2158037573 * c.Z
	local m_ = c.X - 0.1055613458 * c.Y - 0.0638541728 * c.Z
	local s_ = c.X - 0.0894841775 * c.Y - 1.2914855480 * c.Z

	local l = l_ * l_ * l_
	local m = m_ * m_ * m_
	local s = s_ * s_ * s_

	return Vector3.new(
		4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
		-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
	)
end

-- Finds the maximum saturation possible for a given hue that fits in sRGB.
-- Saturation here is defined as S = C/L
-- a and b must be normalised so a^2 + b^2 == 1
function Oklab.compute_max_saturation(
	a: number,
	b: number
): number
	-- Max saturation will be when one of r, g or b goes below zero.

	-- Select different coefficients depending on which component goes below zero first
	local k0, k1, k2, k3, k4, wl, wm, ws

	if -1.88170328 * a - 0.80936493 * b > 1 then
		-- Red component
		k0, k1, k2, k3, k4 = 1.19086277, 1.76576728, 0.59662641, 0.75515197, 0.56771245
		wl, wm, ws = 4.0767416621, -3.3077115913, 0.2309699292
	elseif 1.81444104 * a - 1.19445276 * b > 1 then
		-- Green component
		k0, k1, k2, k3, k4 = 0.73956515, -0.45954404, 0.08285427, 0.12541070, 0.14503204
		wl, wm, ws = -1.2684380046, 2.6097574011, -0.3413193965
	else
		-- Blue component
		k0, k1, k2, k3, k4 = 1.35733652, -0.00915799, -1.15130210, -0.50559606, 0.00692167
		wl, wm, ws = -0.0041960863, -0.7034186147, 1.7076147010
	end

	-- Approximate max saturation using a polynomial
	local S = k0 + k1 * a + k2 * b + k3 * a * a + k4 * a * b

	-- Do one step Halley's method to get closer
	-- this gives an error less than 10e6, except for some blue hues where the dS/dh is close to infinite
	-- this should be sufficient for most applications, otherwise do two/three steps
	local k_l =  0.3963377774 * a + 0.2158037573 * b
	local k_m = -0.1055613458 * a - 0.0638541728 * b
	local k_s = -0.0894841775 * a - 1.2914855480 * b

	do
		local l_ = 1 + S * k_l
		local m_ = 1 + S * k_m
		local s_ = 1 + S * k_s

		local l = l_ * l_ * l_
		local m = m_ * m_ * m_
		local s = s_ * s_ * s_

		local l_dS = 3 * k_l * l_ * l_
		local m_dS = 3 * k_m * m_ * m_
		local s_dS = 3 * k_s * s_ * s_

		local l_dS2 = 6 * k_l * k_l * l_
		local m_dS2 = 6 * k_m * k_m * m_
		local s_dS2 = 6 * k_s * k_s * s_

		local f  = wl * l     + wm * m     + ws * s
		local f1 = wl * l_dS  + wm * m_dS  + ws * s_dS
		local f2 = wl * l_dS2 + wm * m_dS2 + ws * s_dS2

		S = S - f * f1 / (f1*f1 - 0.5 * f * f2)
	end

	return S
end

-- finds L_cusp and C_cusp for a given hue
-- a and b must be normalised so a^2 + b^2 == 1
function Oklab.find_cusp(
	a: number,
	b: number
): (number, number)
	-- First, find the maximum saturation (saturation S = C/L)
	local S_cusp = Oklab.compute_max_saturation(a, b)

	-- Convert to linear sRGB to find the first point where at least one of r,g or b >= 1:
	local rgb_at_max = Oklab.oklab_to_linear_srgb(Vector3.new(1, S_cusp * a, S_cusp * b))
	local L_cusp = cbrt(1 / math.max(rgb_at_max.X, rgb_at_max.Y, rgb_at_max.Z))
	local C_cusp = L_cusp * S_cusp

	return L_cusp, C_cusp
end

-- Finds intersection of the line defined by 
-- L = L0 * (1 - t) + t * L1;
-- C = t * C1;
-- a and b must be normalized so a^2 + b^2 == 1
function Oklab.find_gamut_intersection(
	a: number,
	b: number,
	L1: number,
	C1: number,
	L0: number
): number
	-- Find the cusp of the gamut triangle
	local L_cusp, C_cusp = Oklab.find_cusp(a, b)

	-- Find the intersection for upper and lower half seprately
	local t
	if ((L1 - L0) * C_cusp - (L_cusp - L0) * C1) <= 0 then
		-- Lower half
		t = C_cusp * L0 / (C1 * L_cusp + C_cusp * (L0 - L1))
	else
		-- Upper half
		-- First intersect with triangle
		t = C_cusp * (L0 - 1) / (C1 * (L_cusp - 1) + C_cusp * (L0 - L1))

		-- Then one step Halley's method
		do
			local dL = L1 - L0
			local dC = C1

			local k_l =  0.3963377774 * a + 0.2158037573 * b
			local k_m = -0.1055613458 * a - 0.0638541728 * b
			local k_s = -0.0894841775 * a - 1.2914855480 * b

			local l_dt = dL + dC * k_l
			local m_dt = dL + dC * k_m
			local s_dt = dL + dC * k_s

			-- If higher accuracy is required, 2 or 3 iterations of the following block can be used:
			do
				local L = L0 * (1 - t) + t * L1
				local C = t * C1

				local l_ = L + C * k_l
				local m_ = L + C * k_m
				local s_ = L + C * k_s

				local l = l_ * l_ * l_
				local m = m_ * m_ * m_
				local s = s_ * s_ * s_

				local ldt = 3 * l_dt * l_ * l_
				local mdt = 3 * m_dt * m_ * m_
				local sdt = 3 * s_dt * s_ * s_

				local ldt2 = 6 * l_dt * l_dt * l_
				local mdt2 = 6 * m_dt * m_dt * m_
				local sdt2 = 6 * s_dt * s_dt * s_

				local r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s - 1
				local r1 = 4.0767416621 * ldt - 3.3077115913 * mdt + 0.2309699292 * sdt
				local r2 = 4.0767416621 * ldt2 - 3.3077115913 * mdt2 + 0.2309699292 * sdt2

				local u_r = r1 / (r1 * r1 - 0.5 * r * r2)
				local t_r = -r * u_r

				local g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s - 1
				local g1 = -1.2684380046 * ldt + 2.6097574011 * mdt - 0.3413193965 * sdt
				local g2 = -1.2684380046 * ldt2 + 2.6097574011 * mdt2 - 0.3413193965 * sdt2

				local u_g = g1 / (g1 * g1 - 0.5 * g * g2)
				local t_g = -g * u_g

				local b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s - 1
				local b1 = -0.0041960863 * ldt - 0.7034186147 * mdt + 1.7076147010 * sdt
				local b2 = -0.0041960863 * ldt2 - 0.7034186147 * mdt2 + 1.7076147010 * sdt2

				local u_b = b1 / (b1 * b1 - 0.5 * b * b2)
				local t_b = -b * u_b

				t_r = if u_r >= 0 then t_r else math.huge
				t_g = if u_g >= 0 then t_g else math.huge
				t_b = if u_b >= 0 then t_b else math.huge

				t += math.min(t_r, t_g, t_b)
			end
		end
	end

	return t
end

function Oklab.gamut_clip_preserve_chroma(
	rgb: Vector3
): Vector3
	if rgb.X <= 1 and rgb.Y <= 1 and rgb.Z <= 1 and rgb.X >= 0 and rgb.Y >= 0 and rgb.Z >= 0 then
		return rgb
	end

	local lab = Oklab.linear_srgb_to_oklab(rgb)

	local L = lab.X
	local eps = 0.00001
	local C = math.max(eps, math.sqrt(lab.Y * lab.Y + lab.Z * lab.Z))
	local a_ = if C == 0 then 0 else lab.Y / C
	local b_ = if C == 0 then 0 else lab.Z / C
	local L0 = math.clamp(L, 0, 1)

	local t = Oklab.find_gamut_intersection(a_, b_, L, C, L0)
	local L_clipped = L0 * (1 - t) + t * L
	local C_clipped = t * C

	return Oklab.oklab_to_linear_srgb(Vector3.new(L_clipped, C_clipped * a_, C_clipped * b_))
end

function Oklab.gamut_clip_project_to_0_5(
	rgb: Vector3
): Vector3
	if rgb.X <= 1 and rgb.Y <= 1 and rgb.Z <= 1 and rgb.X >= 0 and rgb.Y >= 0 and rgb.Z >= 0 then
		return rgb
	end

	local lab = Oklab.linear_srgb_to_oklab(rgb)

	local L = lab.X
	local eps = 0.00001
	local C = math.max(eps, math.sqrt(lab.Y * lab.Y + lab.Z * lab.Z))
	local a_ = lab.Y / C
	local b_ = lab.Z / C

	local L0 = 0.5

	local t = Oklab.find_gamut_intersection(a_, b_, L, C, L0)
	local L_clipped = L0 * (1 - t) + t * L
	local C_clipped = t * C

	return Oklab.oklab_to_linear_srgb(Vector3.new(L_clipped, C_clipped * a_, C_clipped * b_))
end

function Oklab.gamut_clip_project_to_L_cusp(
	rgb: Vector3
): Vector3
	if rgb.X <= 1 and rgb.Y <= 1 and rgb.Z <= 1 and rgb.X >= 0 and rgb.Y >= 0 and rgb.Z >= 0 then
		return rgb
	end

	local lab = Oklab.linear_srgb_to_oklab(rgb)

	local L = lab.X
	local eps = 0.00001
	local C = math.max(eps, math.sqrt(lab.Y * lab.Y + lab.Z * lab.Z))
	local a_ = lab.Y / C
	local b_ = lab.Z / C

	-- The cusp is computed here and in find_gamut_intersection, an optimised solution would only compute it once.
	local L_cusp, C_cusp = Oklab.find_cusp(a_, b_)

	local L0 = L_cusp

	local t = Oklab.find_gamut_intersection(a_, b_, L, C, L0)

	local L_clipped = L0 * (1 - t) + t * L
	local C_clipped = t * C

	return Oklab.oklab_to_linear_srgb(Vector3.new(L_clipped, C_clipped * a_, C_clipped * b_))
end

function Oklab.gamut_clip_adaptive_L0_0_5(
	rgb: Vector3,
	alpha: number?
): Vector3
	if rgb.X <= 1 and rgb.Y <= 1 and rgb.Z <= 1 and rgb.X >= 0 and rgb.Y >= 0 and rgb.Z >= 0 then
		return rgb
	end
	local alpha = alpha or 0.05

	local lab = Oklab.linear_srgb_to_oklab(rgb)

	local L = lab.X
	local eps = 0.00001
	local C = math.max(eps, math.sqrt(lab.Y * lab.Y + lab.Z * lab.Z))
	local a_ = lab.Y / C
	local b_ = lab.Z / C

	local Ld = L - 0.5
	local e1 = 0.5 + math.abs(Ld) + alpha * C
	local L0 = 0.5 * (1 + math.sign(Ld) * (e1 - math.sqrt(e1*e1 - 2 * math.abs(Ld))))

	local t = Oklab.find_gamut_intersection(a_, b_, L, C, L0)
	local L_clipped = L0 * (1 - t) + t * L
	local C_clipped = t * C

	return Oklab.oklab_to_linear_srgb(Vector3.new(L_clipped, C_clipped * a_, C_clipped * b_))
end

function Oklab.gamut_clip_adaptive_L0_L_cusp(
	rgb: Vector3,
	alpha: number?
): Vector3
	if rgb.X < 1 and rgb.Y < 1 and rgb.Z < 1 and rgb.X > 0 and rgb.Y > 0 and rgb.Z > 0 then
		return rgb
	end
	local alpha = alpha or 0.05

	local lab = Oklab.linear_srgb_to_oklab(rgb)

	local L = lab.X
	local eps = 0.00001
	local C = math.max(eps, math.sqrt(lab.Y * lab.Y + lab.Z * lab.Z))
	local a_ = lab.Y / C
	local b_ = lab.Z / C

	-- The cusp is computed here and in find_gamut_intersection, an optimized solution would only compute it once.
	local L_cusp, C_cusp = Oklab.find_cusp(a_, b_)

	local Ld = L - L_cusp
	local k = 2 * (if Ld > 0 then 1 - L_cusp else L_cusp)

	local e1 = 0.5*k + math.abs(Ld) + alpha * C/k
	local L0 = L_cusp + 0.5 * (math.sign(Ld) * (e1 - math.sqrt(e1 * e1 - 2 * k * math.abs(Ld))))

	local t = Oklab.find_gamut_intersection(a_, b_, L, C, L0)
	local L_clipped = L0 * (1 - t) + t * L
	local C_clipped = t * C

	return Oklab.oklab_to_linear_srgb(Vector3.new(L_clipped, C_clipped * a_, C_clipped * b_))
end

--[[
	ROBLOX EXTENSIONS
]]

Oklab.default_gamut_clip = Oklab.gamut_clip_adaptive_L0_0_5

local function component_to_gamma(x: number): number
	if x >= 0.0031308 then
		return (1.055) * x^(1.0/2.4) - 0.055
	else
		return 12.92 * x
	end
end

local function component_to_linear(x: number): number
	if x >= 0.04045 then
		return ((x + 0.055)/(1 + 0.055))^2.4
	else 
		return x / 12.92
	end
end

function Oklab.color3_to_linear_srgb(
	c: Color3
): Vector3
	return Vector3.new(
		component_to_linear(c.R),
		component_to_linear(c.G),
		component_to_linear(c.B)
	)
end

function Oklab.linear_srgb_to_color3(
	c: Vector3,
	use_default_gamut_clip: boolean?
): Color3
	if use_default_gamut_clip == false then
		return Color3.new(
			component_to_gamma(c.X),
			component_to_gamma(c.Y),
			component_to_gamma(c.Z)
		)
	else
		local c = Oklab.default_gamut_clip(c)
		return Color3.new(
			math.clamp(component_to_gamma(c.X), 0, 1),
			math.clamp(component_to_gamma(c.Y), 0, 1),
			math.clamp(component_to_gamma(c.Z), 0, 1)
		)
	end


end

--[[
	LCH EXTENSIONS
]]

function Oklab.oklch_to_oklab(oklch: Vector3): Vector3
	return Vector3.new(
		oklch.X,
		oklch.Y * math.cos(oklch.Z * TAU),
		oklch.Y * math.sin(oklch.Z * TAU)
	)
end

function Oklab.oklab_to_oklch(oklab: Vector3): Vector3
	return Vector3.new(
		oklab.X,
		math.sqrt(oklab.Y^2 + oklab.Z^2),
		(math.atan2(oklab.Z, oklab.Y) / TAU) % 1
	)
end

return Oklab