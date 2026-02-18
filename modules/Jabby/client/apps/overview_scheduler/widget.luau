local ui = require(script.Parent.Parent.Parent.Parent.ui)
local vide = require(script.Parent.Parent.Parent.Parent.vide)
local convert_units = require(script.Parent.Parent.Parent.Parent.modules.convert_units)
local types = require(script.Parent.Parent.Parent.Parent.modules.types)
local spawn_app = require(script.Parent.Parent.Parent.spawn_app)
local system_widget = require(script.Parent.Parent.system)
local stack_bar = require(script.Parent.stack_bar)

local create = vide.create
local indexes = vide.indexes
local values = vide.values
local changed = vide.changed
local source = vide.source
local derive = vide.derive

type SystemId = number

type props = {
	host: Player | "server",
	vm: number,
	id: number,

	system_ids: () -> {[SystemId]: true},
	system_data: () -> {[SystemId]: types.SystemData},
	system_frames: () -> {[SystemId]: {types.SystemFrame}},

	pause_system: (SystemId) -> (),
	destroy: () -> ()

}

local function color(n: number)
	return Color3.fromHSV((0.15 * (n-1)) % 1, 1, 1)
end

local sort_by_options = {
	"Name",
	"Id",
	"Frame Time"
}

return function(props: props)

	local selected = source(0)
	local systems_query = source("")
	
	local sort_by = source(2)

	local max_frametime = derive(function()
		local max = 0
		for _, frames in props.system_frames() do
			local sum = 0

			for _, frame in frames do
				sum += frame.s
			end

			max = math.max(max, sum / #frames)
		end
		return max
	end)

	local map_phases_to_systems = derive(function()
		local phases: {[false | string]: {number}} = {[false] = {}}
		for id, data in props.system_data() do
			if phases[data.phase or false] == nil then phases[data.phase or false] = {} end
			table.insert(phases[data.phase or false], id)
		end
		return phases
	end)

	local function system(id: number)
		local gui_state = source(Enum.GuiState.Idle)

		local function frame_time()
			local sum = 0
			local frames = props.system_frames()[id]

			for _, frame in frames do
				sum += frame.s
			end

			return sum / #frames
		end

		local b = create "ImageButton" {
			Name = function()
				return props.system_data()[id].name
			end,
			Size = UDim2.new(1, 0, 0, 32),

			LayoutOrder = function()
				return if sort_by() == 3 then 1e9 - frame_time() * 1e8 else id
			end,

			BackgroundColor3 = function()
				return if gui_state() == Enum.GuiState.Press then
					ui.theme.bg[-1]()
				elseif gui_state() == Enum.GuiState.Hover then
					ui.theme.bg[6]()
				else
					ui.theme.bg[3]()
			end,

			Visible = function()
				return not not string.match(props.system_data()[id].name, systems_query())
			end,

			changed("GuiState", gui_state),

			Activated = function()
				spawn_app.spawn_app(system_widget, {
					host = props.host,
					vm = props.vm,

					scheduler = props.id,
					system = id,
					name = props.system_data()[id].name
				})
			end,

			MouseButton2Click = function()
				props.pause_system(id)
			end,

			-- create a frame that ignores all rules!
			create "Folder" {
				create "Frame" {
					Position = UDim2.new(0, 0, 1, 4),
					AnchorPoint = Vector2.new(0, 1),
					Size = function()
						return UDim2.new(frame_time() / max_frametime(), 0, 0, 1)
					end,

					BackgroundColor3 = ui.theme.fg_on_bg_high[0]

				}
			},

			create "UIStroke" {
				Color = ui.theme.bg[-3]
			},

			create "UICorner" {
				CornerRadius = UDim.new(0, 4)
			},

			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalFlex = Enum.UIFlexAlignment.SpaceEvenly,
				Padding = UDim.new(0, 8)
			},

			ui.padding {
				x = UDim.new(0, 8)
			},

			create "Frame" {
				Size = UDim2.fromOffset(16, 16),
				AnchorPoint = Vector2.new(0.5, 0.5),

				BackgroundColor3 = color(id),

				create "UICorner" {
					CornerRadius = UDim.new(1, 0)
				},
			},

			ui.typography {
				automaticsize = Enum.AutomaticSize.None,
				text = function()
					return props.system_data()[id].name
				end,

				truncate = Enum.TextTruncate.SplitWord,
				xalignment = Enum.TextXAlignment.Left,
				disabled = function()
					return props.system_data()[id].paused
				end,

				create "UIFlexItem" {
					FlexMode = Enum.UIFlexMode.Fill,
					GrowRatio = 1,
					ShrinkRatio = 1
				}
			},

			ui.typography {
				automaticsize = Enum.AutomaticSize.XY,
				text = function()
					local sum = 0
					local frames = props.system_frames()[id]

					for _, frame in frames do
						sum += frame.s
					end

					return `{convert_units("s", sum / #frames)}`
				end,

				xalignment = Enum.TextXAlignment.Right,

				disabled = true,

			},

		}
		return b
	end

	return ui.widget {
		title = "Scheduler",
		subtitle = `host: {props.host} vm: {props.vm} id: {props.id}`,

		min_size = Vector2.new(200, 300),

		bind_to_close = props.destroy,

		create "Frame" {
			Name = "Elements",
			Size = UDim2.fromScale(1, 1),
			AutomaticSize = Enum.AutomaticSize.Y,

			BackgroundTransparency = 1,

			create "UIListLayout" {
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				FillDirection = Enum.FillDirection.Vertical,
				VerticalFlex = Enum.UIFlexAlignment.SpaceBetween,
				Padding = UDim.new(0, 8)
			},

			create "Frame" {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,

				BackgroundTransparency = 1,

				-- create "UIFlexItem" {
				-- 	FlexMode = Enum.UIFlexMode.Custom,
				-- 	GrowRatio = 0,
				-- 	ShrinkRatio = 0
				-- },

				ui.pane {
					name = "Overview",
					size = UDim2.fromScale(1, 0),
		
					create "UIListLayout" {
						FillDirection = Enum.FillDirection.Vertical
					},
	
					ui.typography {
						text = function()
							local run_time = 0
							for id, frames in props.system_frames() do
								if props.system_data()[id].paused then continue end
								local sum = 0

								for _, frame in frames do
									sum += frame.s
								end

								run_time += sum / #frames
							end
	
							return `Run time: {convert_units("s", run_time)}`
						end
					},
	
					stack_bar {
						values = function()
							local v = {}
	
							local system_ids = props.system_ids()
							local system_frames = props.system_frames()
	
							for i = 1, table.maxn(system_ids) do
								if system_ids[i] == nil then continue end
								if props.system_data()[i].paused then continue end

								local sum = 0
								local frames = system_frames[i]

								for _, frame in frames do
									sum += frame.s
								end
	
								table.insert(v, {value = sum / #frames, color = color(i)})
							end
	
							return v
						end,
						selected = selected
					},

					ui.row {
						justifycontent = Enum.UIFlexAlignment.Fill,
						ui.button {
							text = "Pause all",

							activated = function()
								for system, data in props.system_data() do
									if data.paused then continue end
									props.pause_system(system)
								end
							end
						},

						ui.button {
							text = "Resume all",

							activated = function()
								for system, data in props.system_data() do
									if not data.paused then continue end
									props.pause_system(system)
								end
							end
						}
					}
				},

			},

			ui.select {
				size = UDim2.new(1, 0, 0, 30),

				options = sort_by_options,
				selected = sort_by,
				update_selected = function(new)
					-- print(new)
					sort_by(new)
				end
			},

			ui.textfield {
				size = UDim2.new(1, 0, 0, 36),

				placeholder = "System Match",
				
				oninput = systems_query,
			},

			create "ScrollingFrame" {
				Name = "Systems",

				Size = UDim2.fromScale(1, 0),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,

				BackgroundTransparency = 1,

				ScrollBarThickness = 6,
				VerticalScrollBarInset = Enum.ScrollBarInset.Always,
				ScrollBarImageColor3 = ui.theme.fg_on_bg_low[3],

				create "UIFlexItem" {
					FlexMode = Enum.UIFlexMode.Fill
				},

				create "UIListLayout" {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, 8),

					SortOrder = function()
						return if sort_by() == 1 then Enum.SortOrder.Name else Enum.SortOrder.LayoutOrder
					end
				},

				ui.padding {
					y = UDim.new(0, 1),
					x = UDim.new(0, 1)
				},

				values(function()
					return map_phases_to_systems()[false]
				end, system),

				indexes(map_phases_to_systems, function(systems, phase)
					if phase == false then return {} end
					local expanded = source(true)
					-- print(systems())
					return ui.accordion {
						expanded = expanded,
						set_expanded = expanded,
						text = phase,
						
						ui.container {
							Size = UDim2.fromScale(1, 0),

							create "UIListLayout" {
								FillDirection = Enum.FillDirection.Vertical,
								Padding = UDim.new(0, 8),
			
								SortOrder = function()
									return if sort_by() == 1 then Enum.SortOrder.Name else Enum.SortOrder.LayoutOrder
								end
							},
	
							values(systems, system)
						}
					}
				end),

			}

		}

	}

end