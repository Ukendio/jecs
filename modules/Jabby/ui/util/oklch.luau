local oklab = require(script.Parent.Parent.libraries.oklab)

--[=[

Converts OkLCh into a Color3.

lightness is a value between 0-1, determining how "light" a color is.

chroma is a value between 0 to infinity, determining how colorful something is.
current displays can only display a chroma up to around 0.34, and srgb can only
go up to 0.245.

hue is a hue circle from 0-360


]=]
local function oklch(lightness: number, chroma: number, hue: number)
	return oklab.linear_srgb_to_color3(
		oklab.oklab_to_linear_srgb(
			oklab.oklch_to_oklab(
				Vector3.new(math.clamp(lightness, 0, 1), chroma, hue)
			)
		),
		true
	)
end

return oklch