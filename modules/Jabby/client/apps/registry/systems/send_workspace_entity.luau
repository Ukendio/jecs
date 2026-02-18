local UserInputService = game:GetService("UserInputService")

local remotes = require(script.Parent.Parent.Parent.Parent.Parent.modules.remotes)

type Context = {
	host: Player | "server",
	vm: number,
	id: number,

	enable_pick: () -> boolean,

}

return function(context: Context)

	if context.enable_pick() == false then return end

	local location = UserInputService:GetMouseLocation()
	local camera = workspace.CurrentCamera

	local ray = camera:ViewportPointToRay(location.X, location.Y)
	
	remotes.send_mouse_pointer:fire(
		{
			host = context.host,
			to_vm = context.vm
		},
		context.id,
		ray.Origin,
		ray.Direction
	)

end