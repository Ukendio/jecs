local ReplicatedStorage = game:GetService("ReplicatedStorage")
local types = require("../ReplicatedStorage/types")

type Signal<T...> = {
	Connect: (Signal<T...>, fn: (T...) -> ()) -> RBXScriptConnection
}
type Remote<T...> = {
	FireClient: (Remote<T...>, T...) -> (),
	FireAllClients: (Remote<T...>, T...) -> (),
	FireServer: (Remote<T...>) -> (),
	OnServerEvent: {
		Connect: (any, fn: (Player, T...) -> () ) -> ()
	},
	OnClientEvent: {
		Connect: (any, fn: (T...) -> () ) -> ()
	}

}

local function stream_ensure(name): Remote<any>
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	return remote :: any
end

local function datagram_ensure(name): Remote<any>
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new("UnreliableRemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	return remote :: any
end

return {
	input = datagram_ensure("input") :: Remote<string>,
	replication = stream_ensure("replication") :: Remote<{
		[string]: {
			set: { types.Entity }?,
			values: { any }?,
			removed: { types.Entity }?
		}
	}>,

}
