local vide = require(script.Parent.Parent.Parent.Parent.vide)
local anim = require(script.Parent.Parent.Parent.util.anim)
local theme = require(script.Parent.Parent.Parent.util.theme)

local create = vide.create
local read = vide.read

type can<T> = T | () -> T
type props = {

	size: can<UDim2>?,
	position: can<UDim2>?,
	anchorpoint: can<Vector2>?,
	automaticsize: can<Enum.AutomaticSize>?,

	accent: can<boolean>?,

	xalignment: can<Enum.TextXAlignment>?,
	yalignment: can<Enum.TextYAlignment>?,
	truncate: can<Enum.TextTruncate>?,
	wrapped: can<boolean>?,
	
	header: can<boolean>?,
	code: can<boolean>?,
	disabled: can<boolean>?,
	
	text: can<string>,
	textsize: can<number>?,

	visible: can<boolean>?,

	[number]: any

}

return function(props: props)

	local function font()
		return if read(props.code) then theme.code else theme.font
	end

	local function fg()
        local accent = read(props.accent)
		local disabled = read(props.disabled)

        return if accent then
            if disabled then theme.fg_on_acc_low[0]()
            else theme.fg_on_acc_high[0]()
        else
            if disabled then theme.fg_on_bg_low[0]()
            else theme.fg_on_bg_high[0]()
    end

	return create "TextLabel" {

		Size = props.size,
		Position = props.position,
		AnchorPoint = props.anchorpoint,
		AutomaticSize = props.automaticsize or Enum.AutomaticSize.XY,
		AutoLocalize = false,

		TextXAlignment = props.xalignment,
		TextYAlignment = props.yalignment,
		TextTruncate = props.truncate,

		BackgroundTransparency = 1,

		Text = props.text,

		TextSize = props.textsize or function()
			return if read(props.header) then theme.header else theme.body
		end,
		TextWrapped = props.wrapped,
		FontFace = function()
			return if read(props.header) then
				Font.new(font().Family, Enum.FontWeight.Bold)
			else font()
		end,
		TextColor3 = anim(fg),

		Visible = props.visible,

		unpack(props)
	}

end