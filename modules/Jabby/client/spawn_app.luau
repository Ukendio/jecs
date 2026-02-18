local Players = game:GetService("Players")

local vide = require(script.Parent.Parent.vide)
local types = require(script.Parent.Parent.modules.types)

local destroy_fn = {}

local function unmount_all()
	for destroy in destroy_fn do
		destroy()
	end
end

local function spawn_app<T>(app: types.Application<T>, props: T): () -> ()
	return vide.root(function(destroy)

		local destroy = function()
			destroy_fn[destroy] = nil
			destroy()
		end

		local application = app.mount(props, destroy)
		application.Parent = Players.LocalPlayer.PlayerGui

		vide.cleanup(application)
		
		destroy_fn[destroy] = true
		
		return destroy
	end)
end

return {
	unmount_all = unmount_all,
	spawn_app = spawn_app
}