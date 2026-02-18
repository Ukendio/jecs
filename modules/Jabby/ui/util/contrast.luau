local vide = require(script.Parent.Parent.Parent.vide)
local apcaw3 = require(script.Parent.Parent.libraries.apcaw3)
local oklch = require(script.Parent.oklch)

local derive = vide.derive
local read = vide.read

local function min_contrast(options: {
	size: can<number>,
	weight: can<number | Font>?,
	body: can<boolean>?
})

	local size = options.size
	local weight = options.weight or 400
	local needs_body = options.body
	local NO = math.huge

	if not size and not weight then return 0 end

	local MIN_CONTRAST = {
		[12] = {NO, NO, NO, NO, NO, NO, NO, NO, NO},
		[14] = {NO, NO, NO, 100, 100, 90, 75, NO, NO},
		[15] = {NO, NO, NO, 100, 90, 75, 70, NO, NO},
		[16] = {NO, NO, NO, 90, 75, 70, 60, 60, NO},
		[18] = {NO, NO, 100, 75, 70, 60, 55, 55, 55},
		[21] = {NO, NO, 90, 70, 60, 55, 50, 50, 50},
		[24] = {NO, NO, 75, 60, 55, 50, 45, 45, 55},
		[28] = {NO, 100, 70, 55, 50, 45, 43, 43, 43},
		[32] = {NO, 90, 65, 50, 45, 43, 40, 40, 40},
		[36] = {NO, 75, 60, 45, 43, 40, 38, 38, 38},
		[42] = {100, 70, 55, 43, 40, 38, 35, 35, 35},
		[48] = {90, 60, 50, 40, 38, 35, 33, 33, 33},
		[60] = {75, 55, 45, 37, 35, 33, 30 ,30, 30},
		[72] = {60, 50, 40, 35, 33, 30, 30, 30, 30},
		[96] = {50, 45, 35, 33, 30, 30, 30, 30, 30}
	}
	local MIN_CONTRAST_BODY = {
		[12] = {NO, NO, NO, NO, NO, NO, NO, NO, NO},
		[14] = {NO, NO, NO, 100, 100, 90, 75, NO, NO},
		[15] = {NO, NO, NO, 100, 90, 90, 85, NO, NO},
		[16] = {NO, NO, NO, 90, 75, 85, 75, NO, NO},
		[18] = {NO, NO, 100, 75, 85, 75, 70, NO, NO},
		[21] = {NO, NO, 90, 70, 75, 70, 65, NO, NO},
		[24] = {NO, NO, 75, 75, 70, 65, 60, NO, NO},
		[28] = {NO, NO, 85, 70, 65, 60, 58, NO, NO},
		[32] = {NO, NO, 80, 65, 60, 58, 55, NO, NO},
		[36] = {NO, NO, 75, 60, 58, 55, 52, NO, NO},
		[42] = {NO, NO, NO, NO, NO, NO, NO, NO, NO},
		[48] = {NO, NO, NO, NO, NO, NO, NO, NO, NO},
		[60] = {NO, NO, NO, NO, NO, NO, NO, NO, NO},
		[72] = {NO, NO, NO, NO, NO, NO, NO, NO, NO},
		[96] = {NO, NO, NO, NO, NO, NO, NO, NO, NO}
	}

	return derive(function()
		local matrix_to_use =
			if read(needs_body) then MIN_CONTRAST_BODY
			else MIN_CONTRAST
		
		local row_to_use = matrix_to_use[read(size)]
		if not row_to_use then return NO end
		local weight: Font | number = read(weight)
		local font_weight: number = 400

		if type(weight) == "number" then
			font_weight = weight
		elseif typeof(weight) == "Font" then
			font_weight = weight.Weight.Value
		end

		return row_to_use[font_weight // 100] or NO
	end)

end

--- collapses a state to a single value
type recursive<T> = (() -> recursive<T>) | T
type can<T> = (() -> T) | T
local function unwrap<T>(source: recursive<T>): T

	local value: recursive<T>

	while type(source) == "function" do
		source = source()
	end

	value = source

	return value :: T
end

local function get_appropriate_color(options: {
	background: recursive<Color3>?,
	foreground: recursive<{{number}}>,
	elevation: recursive<number>?,
	min_contrast: recursive<number>,
}): () -> Color3

	return function()
		local min_contrast = unwrap(options.min_contrast)
		local elevation = unwrap(options.elevation) or 0
		local bg = unwrap(options.background)
		
		if bg == nil then
			local foreground = unwrap(options.foreground)[1]
			local l, c, h = unpack(foreground, 1, 3)
			local l_a, l_c, l_h = unpack(foreground, 4, 6)
			local color = oklch(
				l + elevation * (l_a or 0),
				c + elevation * (l_c or 0),
				h + elevation * (l_h or 0)
			)
			return color
		end

		if min_contrast == math.huge then
			warn("min contrast is invalid")
		end

		local max = -1
		local furthest_away = Color3.new()
		
		for _, foreground: {number} in unwrap(options.foreground) do
			local l, c, h = unpack(foreground, 1, 3)
			local l_a, l_c, l_h = unpack(foreground, 4, 6)
			local color = oklch(
				l + elevation * (l_a or 0),
				c + elevation * (l_c or 0),
				h + elevation * (l_h or 0)
			)
			local contrast = math.abs(apcaw3.calcAPCA(color, bg, nil, 1, true))

			if max < contrast then
				max = contrast
				furthest_away = color
			end

			if contrast >= min_contrast then
				return color
			end
		end

		-- warn(`unable to find a color, max contrast found is {max // 1} but needs at least {min_contrast}`)
		return furthest_away
	end

end

return {

	min_contrast = min_contrast,
	get_appropriate_color = get_appropriate_color

}