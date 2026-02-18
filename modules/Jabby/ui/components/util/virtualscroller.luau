local vide = require(script.Parent.Parent.Parent.Parent.vide)
local scroll_frame = require(script.Parent.Parent.display.scroll_frame)
local container = require(script.Parent.container)

local create = vide.create
local source = vide.source
local values = vide.values
local changed = vide.changed
local effect = vide.effect
local untrack = vide.untrack
local batch = vide.batch

type can<T> = T | () -> T
type props = {

	size: can<UDim2>?,
	position: can<UDim2>?,
	anchorpoint: can<UDim2>?,

	--- streams in items. when index is -1, should expect to be unused
	item: (index: () -> number) -> Instance,
	--- streams in separators. when index is -1, should expect to be unused
	separator: ((index: () -> number) -> Instance)?,

	item_size: number,
	separator_size: number?,

	max_items: (() -> number)?,

	[number]: any

}

return function(props: props)

	local items = source({} :: {vide.Source<number>})

	local absolute_size = source(Vector2.zero)
	local canvas_position = source(Vector2.zero)

	local item_size = props.item_size
	local separator_size = props.separator_size or 0

	local item = props.item
	local separator = props.separator

	local OVERFLOW = 4

	effect(function()
		local absolute_size = absolute_size()
		local canvas_position = canvas_position()

		local child_size = item_size + separator_size
		local total_required = math.ceil(absolute_size.Y / child_size) + OVERFLOW
		local sources = untrack(items)

		local min_index = math.floor(canvas_position.Y / child_size)
		local max_index = math.ceil((canvas_position.Y + absolute_size.Y) / child_size)

		local max_items = math.huge
		if props.max_items then
			max_items = props.max_items()
		end

		batch(function()
			untrack(function()
				-- mark any sources out of range as unused
				local unused = {}

				for i, s in sources do
					local index = s()

					if
						index >= math.max(min_index, 1)
						and index <= math.min(max_index, max_items)
					then continue end
					unused[i] = true
					s(-1)
				end

				-- add sources necessary
				if #sources < total_required then
					for i = #sources + 1, total_required do
						sources[i] = source(-1)
						unused[i] = true
					end
					items(sources)
				end

				-- update indexes of any sources that went unused
				local did_not_render = {}

				for i = math.max(min_index, 1), math.min(max_index, max_items) do
					did_not_render[i] = true
				end
				

				for _, s in sources do
					did_not_render[s()] = nil
				end

				for index in unused do
					local s = sources[index]
					local key = next(did_not_render)
					if not key then break end
					s(key)
					did_not_render[key] = nil
					unused[index] = nil
				end

				-- remove unnecessary sources
				if #sources > total_required then
					for i = #sources, 1, -1 do
						if unused[i] then
							table.remove(sources, i)
						end
						unused[i] = nil
						if #sources < total_required then break end
					end
					items(sources)
				end

			end)
		end)

	end)

	return scroll_frame {

		unpack(props),

		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorpoint,

		BackgroundTransparency = 1,

		CanvasSize = function()
			if props.max_items then
				return UDim2.fromOffset(0, props.max_items() * (item_size + separator_size))
			else
				local absolute_size = absolute_size()
				local canvas_position = canvas_position()
				local child_size = item_size + separator_size
				local max_index = math.ceil((canvas_position.Y + absolute_size.Y) / child_size) + OVERFLOW
				return UDim2.fromOffset(0, max_index * child_size)
			end
		end,

		values(items, function(index)
			return create "Frame" {
				Name = index,
				AutoLocalize = false,

				Position = function()
					if index() == -1 then UDim2.fromOffset(0, -1000) end
					return UDim2.fromOffset(
						0,
						(item_size + separator_size) * (index() - 1)
					)
				end,
				Size = UDim2.new(1, 0, 0, item_size + separator_size),

				BackgroundTransparency = 1,

				container {
					Name = "Item",
					
					item(index),
				},

				if separator then
					container {
						Name = "Separator",

						separator(index)
					}
				else nil,
				
			}
		end),

		changed("AbsoluteSize", absolute_size),
		changed("CanvasPosition", canvas_position),


	}

end