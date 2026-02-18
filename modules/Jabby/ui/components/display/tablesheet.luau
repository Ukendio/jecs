local vide = require(script.Parent.Parent.Parent.Parent.vide)
local theme = require(script.Parent.Parent.Parent.util.theme)
local button = require(script.Parent.Parent.interactable.button)
local rounded_frame = require(script.Parent.Parent.util.rounded_frame)
local virtualscroller = require(script.Parent.Parent.util.virtualscroller)
local resizeable_bar = require(script.Parent.resizeable_bar)
local scroll_frame = require(script.Parent.scroll_frame)

local create = vide.create
local source = vide.source
local derive = vide.derive
local indexes = vide.indexes

type can<T> = T | () -> T
type table = {
	size: can<UDim2>?,
	suggested_column_sizes: { number }?,

	base_splits: { number }?,
	columns: () -> {{any}},

	on_click: (column: number, row: number) -> (),
	on_click2: (column: number, row: number) -> (),
	read_value: (column: number, row: number) -> string,

	below: {[number]: any}?,
	
	[number]: any
}

return function(props: table)
	local sizes = source({})
	local splits = source({})

	local meaning = derive(function()
		local t = {}

		for i, column in props.columns() do
			t[i] = column[1]
		end

		return t
	end)

	local function get_size(index: number)
		local split_before = splits()[index - 1] or source(0) :: never
		local split_after = splits()[index] or source(1) :: never

		local size = split_after() - split_before()
		return size
	end

	return scroll_frame {
		Size = props.size or UDim2.new(1, 0, 0, 8 * 32),
		CanvasSize = function()
			return UDim2.new(1, 0)
		end,

		create "UIListLayout" {
			VerticalFlex = Enum.UIFlexAlignment.SpaceEvenly
		},
		
		resizeable_bar {
			meaning = meaning,
			sizes = sizes,
			splits = splits,
			base_splits = props.base_splits,
			suggested_sizes = props.suggested_column_sizes
		},

		create "Folder" {

			indexes(meaning, function(_, i)
				return create "Frame" {
					Size = UDim2.new(0, 1, 1, -32),
					AutoLocalize = false,
					Position = function()
						local pos = splits()[i]
						return if not pos then UDim2.fromScale(0, 0) else UDim2.fromScale(pos(), 0)
					end,

					BackgroundColor3 = theme.bg[-1],

					ZIndex = 100
				}
			end)
		},

		virtualscroller {
			size = UDim2.fromScale(1, 0),

			create "UIFlexItem" {
				FlexMode = Enum.UIFlexMode.Grow,
			},

			{
				BackgroundColor3 = theme.bg[0],
				VerticalScrollBarInset = Enum.ScrollBarInset.None,
				BackgroundTransparency = 0,
			},

			item_size = 32,
			item = function(index)
				
				return create "Frame" {
					Size = UDim2.new(1, 0, 0, 32),
					AutoLocalize = false,

					BackgroundColor3 = theme.bg[2],

					create "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 0)
					},

					create "UIStroke" {
						Color = theme.bg[-1],
					},

					indexes(props.columns, function(column, i)
						return button {
							size = function()
								local column_size = get_size(i)
								return UDim2.new(column_size, 0, 0, 32)
							end,

							text = function()
								return props.read_value(i, index() + 1) or ""
							end,

							create "UIListLayout" {
								FillDirection = Enum.FillDirection.Horizontal,
								VerticalAlignment = Enum.VerticalAlignment.Center
							},

							xalignment = Enum.TextXAlignment.Left,

							corner = false,
							stroke = false,
							code = true,

							activated = function()
								props.on_click(i, index() + 2)
							end,

							mouse2 = function()
								props.on_click2(i, index() + 2)
							end
						} :: Instance
					end)

				}
	
			end,

			max_items = function()
				local value = (props.columns()[1] ~= nil and #props.columns()[1] or 0)
				return value - 1
			end,
			
	
		},

		rounded_frame {
			size = function()
				return UDim2.new(1, 0, 0, 32)
			end,

			color = theme.bg[1],

			props.below,

			bottomleft = UDim.new(0, 8),
			bottomright = UDim.new(0, 8),
		},

		unpack(props)
	}
end