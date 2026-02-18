local vide = require(script.Parent.Parent.Parent.Parent.vide)
local anim = require(script.Parent.Parent.Parent.util.anim)
local theme = require(script.Parent.Parent.Parent.util.theme)

local create = vide.create
local read = vide.read

type can<T> = (() -> T) | T

type Background = {
    position: can<UDim2>?,
    size: can<UDim2>?,
    anchorpoint: can<UDim2>?,
    automaticsize: can<Enum.AutomaticSize>?,

    layoutorder: can<number>?,
    zindex: can<number>?,

    checked: can<boolean>,

    [number]: any
}

return function(props: Background)

    return create "Frame" {
        Position = props.position,
        Size = props.size or UDim2.fromOffset(24, 24),
        AnchorPoint = props.anchorpoint or Vector2.new(0.5, 0.5),
        AutomaticSize = props.automaticsize,
        AutoLocalize = false,

        LayoutOrder = props.layoutorder,

        ZIndex = props.zindex,

        BackgroundColor3 = anim(function()
            return if read(props.checked) then theme.acc[3]() else theme.bg[1]()
        end),

        create "UIStroke" {
            Color = function()
                return if read(props.checked) then theme.acc[0]() else theme.bg[-3]()
            end
        },

        create "UICorner" {
            CornerRadius = UDim.new(0, 4)
        },

        create "ImageLabel" {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,

            Image = "rbxassetid://100188624502987",
            ImageTransparency = anim(function()
                return if read(props.checked) then 0 else 1
            end)
        },

        unpack(props)
        
    }
end