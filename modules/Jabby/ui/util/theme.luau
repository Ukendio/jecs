--[[

simple theme engine for computing colors
]]

local vide = require(script.Parent.Parent.Parent.vide)
local apcaw3 = require(script.Parent.Parent.libraries.apcaw3)
local contrast = require(script.Parent.contrast)
local oklch_to_color3 = require(script.Parent.oklch)

local source = vide.source

local function oklch(t: {number})
    return table.freeze {
        l = t[1],
        c = t[2],
        h = t[3],
        color = oklch_to_color3(unpack(t))
    }
end

local background = source(oklch {0.2012, 0.01, 0.6}) -- note: for light mode change this to 0.9012 from 0.3012
local accent = source(oklch {0.52, 0.21, 0.71}) -- note: for light mode change this to 0.62 from 0.52

local BODY_SIZE = 18
local HEADER_SIZE = 24
local FONT = Font.fromName(
    "BuilderSans",
    Enum.FontWeight.Regular,
    Enum.FontStyle.Normal
)
local FONT_CODE = Font.new(
    "rbxassetid://16658246179",
    Enum.FontWeight.Regular,
    Enum.FontStyle.Normal
)

--- determines when it should be decreasing instead of increasing
local function should_flip(lightness: number)
    return lightness > 0.65
end

local CONTRAST_LOW = 0.4
local CONTRAST_HIGH = 0.7

type Depth = number
type ColorPalette = {

    bg: {[Depth]: Color3},
    fg_on_bg_high: {[Depth]: Color3},
    fg_on_bg_low: {[Depth]: Color3},
    fg_on_accent: {[Depth]: Color3},
    accent: Color3,

}

local function compute_bg(depth: Depth)
    local function get()
        local bg = background()
        -- print(bg.l + 0.01 * depth, depth, bg.c, bg.h)

        return oklch {
            math.clamp(bg.l + 0.02 * depth, 0, 1),
            bg.c,
            bg.h
        }
        -- if should_flip(bg.l) then
        --     return oklch {
        --         math.clamp(bg.l - 0.02 * depth, 0, 1),
        --         bg.c,
        --         bg.h
        --     }
        -- else
        --     return oklch {
        --         math.clamp(bg.l + 0.02 * depth, 0, 1),
        --         bg.c,
        --         bg.h
        --     }
        -- end
    end

    return function(raw: boolean)
        local c = if raw then get() else get().color
        return c
    end :: ((true) -> typeof(oklch {}) ) & (false?) -> Color3
end

local function compute_acc(depth: Depth)
    local function get()
        local bg = accent()
        -- print(bg.l + 0.01 * depth, depth, bg.c, bg.h)
        return oklch {
            math.clamp(bg.l + 0.02 * depth, 0, 1),
            bg.c,
            bg.h
        }
        -- if should_flip(bg.l) then
        --     return oklch {
        --         math.clamp(bg.l - 0.02 * depth, 0, 1),
        --         bg.c,
        --         bg.h
        --     }
        -- else
        --     return oklch {
        --         math.clamp(bg.l + 0.02 * depth, 0, 1),
        --         bg.c,
        --         bg.h
        --     }
        -- end
    end

    return function(raw: boolean)
        local c = if raw then get() else get().color
        return c
    end :: ((true) -> typeof(oklch {}) ) & (false?) -> Color3
end

local function compute_fg_on_bg_high(depth: Depth)
    local get_bg = compute_bg(depth)
    return function()
        local bg = get_bg(true)
        
        if should_flip(bg.l) then
            return oklch {
                bg.l - CONTRAST_HIGH,
                bg.c, bg.h
            }.color
        else
            return oklch {
                bg.l + CONTRAST_HIGH,
                bg.c, bg.h
            }.color
        end
    end
end

local function compute_fg_on_bg_low(depth: Depth)
    local get_bg = compute_bg(depth)
    return function()
        local bg = get_bg(true)
        
        if should_flip(bg.l) then
            return oklch {
                bg.l - CONTRAST_LOW,
                bg.c, bg.h
            }.color
        else
            return oklch {
                bg.l + CONTRAST_LOW,
                bg.c, bg.h
            }.color
        end
    end
end

local function compute_fg_on_acc_low(depth: Depth)
    local get_bg = compute_acc(depth)
    return function()
        local bg = get_bg(true)
        
        if should_flip(bg.l) then
            return oklch {
                bg.l - CONTRAST_LOW,
                bg.c, bg.h
            }.color
        else
            return oklch {
                bg.l + CONTRAST_LOW,
                bg.c, bg.h
            }.color
        end
    end
end

local function compute_fg_on_acc_high(depth: Depth)
    local get_bg = compute_acc(depth)
    return function()
        local bg = get_bg(true)
        
        if should_flip(bg.l) then
            return oklch {
                bg.l - CONTRAST_HIGH,
                bg.c, bg.h
            }.color
        else
            return oklch {
                bg.l + CONTRAST_HIGH,
                bg.c, bg.h
            }.color
        end
    end
end

type Theme = {

    bg: {[Depth]: number},
    accent: Color3,

    fg_on_bg_high: {[Depth]: Color3},
    fg_on_bg_low: {[Depth]: Color3},
    fg_on_accent_high: {[Depth]: Color3},
    fg_on_accent_low: {[Depth]: Color3},
    
    body: number,
    header: number,
    font: Font,
    font_code: Font,

}

local function compute_theme()

    local MAX_DEPTH = 20
    local MIN_DEPTH = -20

    local theme = {
        bg = {},
        acc = {},

        fg_on_bg_high = {},
        fg_on_bg_low = {},
        fg_on_acc_high = {},
        fg_on_acc_low = {},
        
        body = BODY_SIZE,
        header = HEADER_SIZE,
        font = FONT,
        code = FONT_CODE
    }

    for i = MIN_DEPTH, MAX_DEPTH do
        theme.bg[i] = compute_bg(i)
        theme.acc[i] = compute_acc(i)
        theme.fg_on_acc_high[i] = compute_fg_on_acc_high(i)
        theme.fg_on_acc_low[i] = compute_fg_on_acc_low(i)
        theme.fg_on_bg_high[i] = compute_fg_on_bg_high(i)
        theme.fg_on_bg_low[i] = compute_fg_on_bg_low(i)
    end

    return theme

end

return setmetatable({

    settings = {
        background = background,
        accent = accent
    },

}, {
    __index = compute_theme()
})