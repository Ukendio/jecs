local ReplicatedStorage = game:GetService("ReplicatedStorage")
local types = require("../ReplicatedStorage/types")

type Remote<T...> = {
	FireClient: (Remote<T...>, Player, T...) -> (),
	FireAllClients: (Remote<T...>, T...) -> (),
	FireServer: (Remote<T...>, T...) -> (),
	OnServerEvent: RBXScriptSignal<(Player, T...)>,
	OnClientEvent: RBXScriptSignal<T...>
}

local function stream_ensure(name)
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	return remote
end

local function datagram_ensure(name)
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new("UnreliableRemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	return remote
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
