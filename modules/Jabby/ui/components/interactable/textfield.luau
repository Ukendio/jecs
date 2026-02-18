local vide = require(script.Parent.Parent.Parent.Parent.vide)
local anim = require(script.Parent.Parent.Parent.util.anim)
local theme = require(script.Parent.Parent.Parent.util.theme)
local typography = require(script.Parent.Parent.display.typography)
local padding = require(script.Parent.Parent.util.padding)

local create = vide.create
local source = vide.source
local changed = vide.changed
local effect = vide.effect
local action = vide.action
local read = vide.read

type can<T> = T | () -> T
type props = {

    size: can<UDim2>?,
    position: can<UDim2>?,
    anchorpoint: can<UDim2>?,
    
    text: can<string>?,
    placeholder: can<string>?,

    multiline: can<boolean>?,
    code: can<boolean>?,

    disabled: can<boolean>?,

    stroke: can<boolean>?,
    corner: can<boolean>?,

    --- called whenever a character is added / removed
    oninput: ((new: string) -> ())?,
    --- called whenever focus is lost
    focuslost: ((text: string, enter: boolean?) -> ())?,
    --- called whenever focus is lost by pressing enter
    enter: ((text: string) -> ())?,

}

return function(props: props)

    local guistate = source(Enum.GuiState.Idle)
    local focused = source(false)
    local textbox = source() :: vide.Source<TextBox>
    local text = source("")

    effect(function()
        text(read(props.text) or "")
    end)

    local function bg()
        local guistate = guistate()

        return if guistate == Enum.GuiState.NonInteractable then theme.bg[0]()
            elseif focused() then theme.bg[-3]()
            else theme.bg[-2]()
    end

    local function fg()
        local disabled = read(props.disabled)

        return if disabled then theme.fg_on_bg_low[0]()
            else theme.fg_on_bg_high[0]()
    end

    local function stroke()
        local guistate = guistate()

        return if guistate == Enum.GuiState.NonInteractable then theme.bg[-3]()
            elseif focused() then theme.acc[5]()
            elseif guistate == Enum.GuiState.Idle then theme.bg[-3]()
            elseif guistate == Enum.GuiState.Hover then theme.bg[3]()
            else theme.bg[-3]()
    end

    -- this effect will automatically focus the textbox if focused is true
    effect(function()
        if focused() == true and textbox() then
            textbox():CaptureFocus()
        end
    end)

    return create "TextButton" {

        Name = props.placeholder or "Textbox",
        AutoLocalize = false,

        Size = props.size or UDim2.fromOffset(300, 30),
        Position = props.position,
        AnchorPoint = props.anchorpoint,

        Activated = function()
            focused(true)
        end,

        Interactable = function()
            return not props.disabled 
        end,

        BackgroundColor3 = anim(bg),

        ClipsDescendants = true,

        create "TextBox" {

            Size = UDim2.fromScale(1, 1),
			AutoLocalize = false,

            MultiLine = props.multiline,

            BackgroundTransparency = 1,

            Focused = function()
                focused(true)
            end,

            FocusLost = function(enter)
                focused(false)
                if props.focuslost then
                    props.focuslost(text(), enter)
                end

                if props.enter then
                    props.enter(text())
                end
            end,

            TextSize = theme.body,
            FontFace = function()
                return if read(props.code) then theme.code else theme.font
            end,
            TextColor3 = anim(fg),
            PlaceholderColor3 = theme.fg_on_bg_low[0],

            PlaceholderText = props.placeholder,
            Text = props.text,

            ClipsDescendants = true,

            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = function()
                return if read(props.multiline) then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center
            end,

            action(textbox),
            changed("Text", text),
            if props.oninput then changed("Text", props.oninput) else nil

        },

        create "UIStroke" {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            
            Color = anim(stroke),
            Thickness = 1,
            Enabled = props.stroke
        },

        create "UICorner" {
            CornerRadius = function()
                return if read(props.corner) == false then UDim.new() else UDim.new(0, 4)
            end
        },

        padding {
            x = UDim.new(0, 8),
            y = UDim.new(0, 2)
        },

        changed("GuiState", guistate)

    }

end