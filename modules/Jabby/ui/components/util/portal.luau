--[[

portal is used to render a component over other components.
it will find the nearest layer collector to parent itself and it's descendants
onto, and if inherit_layout is enabled, inherits the nearest guibase2d's size and
position properties.

]]
local vide = require(script.Parent.Parent.Parent.Parent.vide)

local create = vide.create
local source = vide.source
local effect = vide.effect
local cleanup = vide.cleanup
local ref = vide.action
local read = vide.read

type can<T> = T | () -> T
type portal = {
	--- controls if the portal should inherit the layout of the frame it's under
	inherit_layout: can<boolean>?,

	[number]: Instance,
}

local layout = 100_000

local function portal(props: portal)

	local inherit_layout = props.inherit_layout

	local nearest_gui_base = source(nil :: GuiBase2d?)
	local nearest_layer_collector = source(nil :: LayerCollector?)

	local size = source(UDim2.fromScale(1, 1))
	local position = source(UDim2.fromScale(0, 0))
	local reference = source(nil :: Configuration?)

	-- this will create connections to update the size and position sources
	effect(function()
		local object = nearest_gui_base()
		if not object then return end
		
		local function update()
			size(UDim2.fromOffset(object.AbsoluteSize.X, object.AbsoluteSize.Y))
			position(UDim2.fromOffset(object.AbsolutePosition.X, object.AbsolutePosition.Y))
		end

		cleanup(object:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))
		cleanup(object:GetPropertyChangedSignal("AbsolutePosition"):Connect(update))
	end)

	-- creates a container that is mounted to somewhere.
	cleanup(vide.mount(function()
		cleanup(create "Frame" {

			Name = `Portal:{layout}`,
			Parent = nearest_layer_collector,
			AutoLocalize = false,
			ZIndex = layout,

			Size = function()
				return if read(inherit_layout) == true then size()
				else UDim2.fromScale(1, 1)
			end,
			Position = function()
				return if read(inherit_layout) == true then position()
				else UDim2.fromScale(0, 0)
			end,

			BackgroundTransparency = 1,

			unpack(props)

		})
	end))

	-- this is an anchor used to reference what gui base and layer collector to use.
	return create "Configuration" {
		Name = `PortalAnchor:{layout}`,

		AncestryChanged = function()
			local reference = reference()
			if not reference then
				nearest_gui_base(nil)
				return
			end
			nearest_gui_base(reference:FindFirstAncestorWhichIsA("GuiBase2d"))
			nearest_layer_collector(reference:FindFirstAncestorWhichIsA("LayerCollector"))
		end,

		ref(function(instance)
			layout += 1
			reference(instance)
			nearest_gui_base(instance:FindFirstAncestorWhichIsA("GuiBase2d"))
			nearest_layer_collector(instance:FindFirstAncestorWhichIsA("LayerCollector"))
		end)
	}
	
end

return portal