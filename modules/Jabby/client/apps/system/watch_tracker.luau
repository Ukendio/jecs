local ui = require(script.Parent.Parent.Parent.Parent.ui)
local vide = require(script.Parent.Parent.Parent.Parent.vide)
local types = require(script.Parent.Parent.Parent.Parent.modules.types)
local tooltip = require(script.Parent.Parent.Parent.components.tooltip)
local virtualscroller_horizontal = require(script.Parent.Parent.Parent.components.virtualscroller_horizontal)

local create = vide.create
local source = vide.source

type props = {
	host: "server" | Player,
	vm: number,

	scheduler: number,
	system: number,
	name: string,

	recording: vide.Source<boolean>,
	watching_frame: vide.Source<number>,
	per_frame_data: () -> {[number]: number},
	changes: () -> types.WatchLoggedChanges,
}

local PROFILER_THICKNESS = 6

return function(props: props)

	local is_recording = props.recording
	local watching_frame = props.watching_frame
	local per_frame_data = props.per_frame_data
	local changes = props.changes

	local function sheet_changes()
		local changes = changes()

		return {
			{"type", unpack(changes.types)},
			{"entity", unpack(changes.entities)},
			{"component", unpack(changes.component)},
			{"value", unpack(changes.values)}
		}
	end

	local function max()
		return math.max(1, unpack(per_frame_data()))
	end
	
	local function total_changes()
		local sum = 0
		for _, value in per_frame_data() do
			sum += value
		end
		return sum
	end

	local hovering_over = source(false)

	return ui.list {
		justifycontent = Enum.UIFlexAlignment.SpaceEvenly,
		spacing = UDim.new(0, 4),

		ui.pane {
			virtualscroller_horizontal {
				item_size = PROFILER_THICKNESS,
				item = function(index)
					local function value()
						return per_frame_data()[index()] or 0
					end

					return create "TextButton" {
						Size = function()
							return UDim2.new(0, PROFILER_THICKNESS, 1, 0)
						end,
						BackgroundTransparency = function()
							return if hovering_over() == index() then 0.5 else 1
						end,
						BackgroundColor3 = ui.theme.bg[10],
						
						MouseEnter = function()
							hovering_over(index())
						end,
						MouseLeave = function()
							if hovering_over() ~= index() then return end
							hovering_over(false)
						end,
						Activated = function()
							watching_frame(index())
						end,
						AutoLocalize = false,

						create "Frame" {
							Size = function()
								return UDim2.fromScale(1, value() / max())
							end,
							Position = UDim2.fromScale(1, 1),
							AnchorPoint = Vector2.new(1, 1),
							BackgroundColor3 = function()
								return if watching_frame() == index() then
									ui.theme.acc[20]()
								elseif hovering_over() == index() then
									ui.theme.acc[5]()
								else ui.theme.acc[0]()
							end,
						}

					}
				end,
				max_items = function()
					return #per_frame_data()
				end,

				create "UIStroke" {Color = ui.theme.bg[-3]},

				{
					Size = UDim2.new(1, 0, 0, 56),
					HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
					BackgroundColor3 = ui.theme.bg[-1],
					ScrollBarThickness = 6,

					CanvasPosition = function()
						per_frame_data()
						return Vector2.new(table.maxn(per_frame_data()) * PROFILER_THICKNESS)
					end,
				}
			},

			ui.typography {
				text = function()
					return `Recorded {#per_frame_data()} frames and tracked {total_changes()} changes`
				end
			},

			ui.typography {
				text = function()
					return `Currently viewing frame {watching_frame()}`
				end
			}
		},

		tooltip {
			transparency = 0,
			visible = function()
				return hovering_over() ~= false
			end,
			
			ui.typography {
				automaticsize = Enum.AutomaticSize.XY,

				text = function()
					return `\z
					Frame: #{hovering_over()}\n\z
					Changes: {per_frame_data()[hovering_over()] or 0}`
				end,
				xalignment = Enum.TextXAlignment.Left,
				wrapped = true
			}
		},
		
		ui.container {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = ui.theme.bg[1],
			BackgroundTransparency = 0,

			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalFlex = Enum.UIFlexAlignment.SpaceEvenly,
				VerticalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 8)
			},

			ui.padding {
				x = UDim.new(0, 4),
				y = UDim.new(0, 4)
			},

			ui.button {
				size = UDim2.new(0, 80, 0, 30),
				automaticsize = Enum.AutomaticSize.X,
				text = function()
					return if is_recording() then "Pause" else "Record"
				end,

				activated = function()
					is_recording(not is_recording())
				end
			},
			
			ui.container {
				Size = UDim2.fromScale(0, 0),

				create "UIFlexItem" {
					FlexMode = Enum.UIFlexMode.Fill
				},

				ui.textfield {
					size = UDim2.new(1, 0, 1, 0),
					text = tostring(watching_frame()),
					placeholder = "frame",

					enter = function(text: string)
						if tonumber(text) == nil then return end
						watching_frame(tonumber(text)) 
					end
				}
			},

		},

		ui.container {
			Size = UDim2.fromScale(1, 1),
			
			create "UIFlexItem" {
				FlexMode = Enum.UIFlexMode.Fill
			},

			ui.tablesheet {
				size = UDim2.fromScale(1, 1),

				column_sizes = source {100, 80, 100, 200},
				read_value = function(column, row)
					local v = sheet_changes()[column][row]
					return if v == false then "" else v
				end,

				on_click = function() end,
				on_click2 = function() end,

				columns = sheet_changes
			}

		}
	}

end