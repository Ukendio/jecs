--[[

container is a basic transparent frame that covers the entire frame.

]]

local vide = require(script.Parent.Parent.Parent.Parent.vide)

local create = vide.create

local function container(props: vide.vFrame)
	return create "Frame" {

		Name = "Container",
		AutoLocalize = false,
		
		Size = UDim2.fromScale(1, 1),

		BackgroundTransparency = 1,

		props,
	}
end

return container
