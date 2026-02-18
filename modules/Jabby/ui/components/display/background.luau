local vide = require(script.Parent.Parent.Parent.Parent.vide)
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

    depth: can<number>?,
    accent: can<boolean>?,

    [number]: any
}

return function(props: Background)

    return create "Frame" {
        Position = props.position,
        Size = props.size or UDim2.fromScale(1, 1),
        AnchorPoint = props.anchorpoint,
        AutomaticSize = props.automaticsize,
        AutoLocalize = false,

        LayoutOrder = props.layoutorder,

        ZIndex = props.zindex,

        BackgroundColor3 = function()
            return
                if read(props.accent) then theme.acc[read(props.depth) or 0]()
                else theme.bg[read(props.depth) or 0]()
        end,

        unpack(props)
        
    }
end