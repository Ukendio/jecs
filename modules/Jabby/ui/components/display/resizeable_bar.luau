local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local vide = require(script.Parent.Parent.Parent.Parent.vide)
local theme = require(script.Parent.Parent.Parent.util.theme)
local padding = require(script.Parent.Parent.util.padding)
local rounded_frame = require(script.Parent.Parent.util.rounded_frame)
local typography = require(script.Parent.typography)

local create = vide.create
local source = vide.source
local derive = vide.derive
local effect = vide.effect
local cleanup = vide.cleanup
local indexes = vide.indexes
local changed = vide.changed
local untrack = vide.untrack

local MAX_PIXELS_OFFSET = 32

local BEFORE = source(0)
local AFTER = source(1)

type ResizeableBar = {
    meaning: () -> { string },
    min_sizes: (() -> { vide.source<number>? })?,
    sizes: vide.source<{ vide.source<number> }>,
    suggested_sizes: { number }?,

    splits: (vide.source<{ vide.source<number> }>)?,
    base_splits: { number }?

}

return function(props: ResizeableBar)
    local meaning = props.meaning
	local sizes = props.sizes
	local min_sizes = props.min_sizes or source({}) :: never
    local suggested_sizes = props.suggested_sizes or {}

	local absolute_size = source(Vector2.one)
	local absolute_position = source(Vector2.one)

	local total = derive(function()
		return #meaning()
	end)

	local splits = props.splits or source {}
	local total_columns = derive(function()
		return #props.meaning()
	end)

	effect(function(previous)
		local new = {}

		for i = 1, total_columns() - 1 do
			local old_split = vide.read(previous and previous[i] or nil)
			new[i] = source(math.min(if old_split and old_split ~= 1 then old_split else suggested_sizes[i] or 1, i / total_columns()))
		end

		splits(new)
		return new
	end)

	for i, split in (props.base_splits :: never) or {} do
		splits()[i](split)
	end

	local function get_size(index: number)
		local split_before = splits()[index - 1] or BEFORE :: never
		local split_after = splits()[index] or AFTER :: never

		local size = split_after() - split_before()
		return size
	end

	local function get_min_size(i: number)
		local min_size = min_sizes()[i]
		return min_size and min_size() or 0.025
	end

	effect(function()
		local new = setmetatable({}, {
			__index = function()
				return function() return 0 end
			end,
		})

		for i = 1, total() do
			min_sizes()[i] = min_sizes()[i] or source(0.025)
			untrack(function()
				new[i] = derive(function()
					return get_size(i)
				end)
			end)
		end

		sizes(new :: any)
	end)

	local down = false
	local updating = 0

    return rounded_frame {
        size = function()
            return UDim2.new(1, 0, 0, 32)
        end,
        topleft = UDim.new(0, 8),
        topright = UDim.new(0, 8),
        color = theme.bg[1],

        create "TextButton" {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
			AutoLocalize = false,
            Text = "",

            create "UIListLayout" {
                FillDirection = Enum.FillDirection.Horizontal,
                Padding = UDim.new(0, 0)
            },

            indexes(meaning, function(column, i)
                return typography {
                    size = function()
                        return UDim2.fromScale(get_size(i), 1)
                    end,
                    automaticsize = Enum.AutomaticSize.None,
                    text = function()
                        return column() or ""
                    end,
                    xalignment = Enum.TextXAlignment.Left,
                    truncate = Enum.TextTruncate.AtEnd,
                    header = true,
                    textsize = 18,

                    padding {x = UDim.new(0, 8)}
                }
            end),

            changed("AbsoluteSize", absolute_size),
            changed("AbsolutePosition", absolute_position),

            MouseButton1Down = function(x: number)
                -- find the nearest split
                x -= absolute_position().X
                local absolute_size = absolute_size()
                local nearest = -1
                for i, location in splits() do
                    local absolute_x = absolute_size.X * location()
                    if math.abs(x - absolute_x) > MAX_PIXELS_OFFSET then continue end
    
                    nearest = i
                end
    
                down = nearest ~= -1
                updating = nearest
            end,
    
            MouseButton1Up = function()
                down = false
            end,

            cleanup(RunService.Heartbeat:Connect(function()
                local x = UserInputService:GetMouseLocation().X
    
                x -= absolute_position().X
                if down == false then return end
                down = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) == true
    
                local relative = x / absolute_size().X
                local current = splits()[updating]()
                local left_to_move = relative - current
    
                if left_to_move > 0 then
                    for i = updating, total() - 1, 1 do
                        local min_size = get_min_size(i + 1)
                        local size = get_size(i + 1)
    
                        local new_size = math.max(size - left_to_move, min_size)
                        local difference = size - new_size
    
                        splits()[i](splits()[i]() + difference)
                        left_to_move -= difference
    
                        if left_to_move == 0 then break end
                    end
                else
                    for i = updating, 1, -1 do
                        local min_size = get_min_size(i)
    
                        local size = math.max(get_size(i), min_size) -- this is changing, which it isnt supposed to do
    
                        local new_size = math.max(size + left_to_move, min_size)
                        local difference = new_size - size
    
                        splits()[i](splits()[i]() + difference)
                        --assert((new_size + difference) == get_size(i - 1))
                        left_to_move -= difference
    
                        if left_to_move == 0 then break end
                    end
                end
            end)),
        }

    }
end