--[[

	net is a utility library designed to handle connections to other actors and
	the server for me.

]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local signal = require(script.Parent.signal)
local vm_id = require(script.Parent.vm_id)
local traffic_check = require(script.Parent.traffic_check)
local types = require(script.Parent.types)

local local_host: "server" | Player
local MANAGER_VM = 0

if RunService:IsServer() then
	local_host = "server"
else
	local_host = Players.LocalPlayer
end

local function tincoming_connector(t: any): boolean
	if typeof(t) ~= "table" then return false end
	if not (t.host == "server" or (typeof(t.host) == "Instance" and t.host:IsA("Player"))) then return false end
	if typeof(t.from_vm) ~= "number" then return false end
	if t.to_vm ~= nil and typeof(t.to_vm) ~= "number" then return false end

	return true
end

local NAME = "JABBY_REMOTES"
local folder: Instance
local created_folder = false
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(NAME)
	if existing then
		folder = existing
	else
		created_folder = true
		warn("\z
		There's a bug with jabby that sometimes causes the JABBY_REMOTES folder to not replicate very rarely. \z
		Unfortunately, I still haven't thought of a fix yet -,- so please instead clone the JABBY_REMOTES \z
		folder into your game which should stop it. make sure to set archivable to true!")
		folder = Instance.new("Folder")
		folder.Name = NAME
		folder.Archivable = false
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild(NAME)
end

local function get_remote_event(name: string, unreliable: boolean?): RemoteEvent & { actor: BindableEvent, peer: RemoteEvent }
	if RunService:IsServer() then
		return folder:FindFirstChild(name) :: RemoteEvent & { actor: BindableEvent }
			or (function()
				if not created_folder then
					warn(`btw, you are missing {name} from the JABBY_REMOTES folder`)
				end

				local remote = Instance.new(if unreliable then "UnreliableRemoteEvent" else "RemoteEvent")
				remote.Name = name
				remote.Parent = folder

				local fire_actor = Instance.new("BindableEvent")
				fire_actor.Name = "actor"
				fire_actor.Parent = remote
				
				local peer = Instance.new("RemoteEvent")
				peer.Name = "peer"
				peer.Parent = remote

				return remote :: RemoteEvent & { actor: BindableEvent, peer: RemoteEvent }
			end)()
	else
		return folder:WaitForChild(name) :: RemoteEvent & { actor: BindableEvent }
	end
end

local function create_event<T...>(name: string, unreliable: boolean?, do_not_block_traffic: boolean?)
	local remote = get_remote_event(name, unreliable)
	local on_event_fire, fire = signal()

	local event = {
		type = "event",

		fire = function(_, connector: types.OutgoingConnector, ...)
			--- if the host is within this vm, we can fire it straight to
			if not traffic_check.check(local_host, connector.host, true) then return end
			
			-- same host, same vm.
			if
				connector.host == local_host
				and connector.to_vm == vm_id
			then

				local incoming = {
					host = local_host,
					from_vm = vm_id,
					to_vm = connector.to_vm
				}

				fire(incoming, ...)
			--- if the host is the same, but in a separate actor
			--- we have to fire the actor
			elseif
				connector.host == local_host
				and connector.to_vm ~= vm_id
			then
				local incoming = {
					host = local_host,
					from_vm = vm_id,
					to_vm = connector.to_vm
				}

				remote.actor:Fire(incoming, ...)
			--- we need to fire the server
			elseif connector.host == "server" then
				local incoming = {
					host = "server",
					from_vm = vm_id,
					to_vm = connector.to_vm
				}

				remote:FireServer(incoming, ...)
			--- we need to fire the client
			elseif local_host == "server" then
				local incoming = {
					host = "server",
					from_vm = vm_id,
					to_vm = connector.to_vm
				}

				remote:FireClient(connector.host, incoming, ...)
			--- we need to tell the server to redirect this to the client
			else
				local incoming = {
					host = connector.host,
					from_vm = vm_id,
					to_vm = connector.to_vm
				}

				remote:FireServer(incoming, ...)
			end

		end,

		connect = function(_, callback: (types.IncomingConnector, T...) -> ())
			return on_event_fire:connect(callback :: any)
		end
	}

	if RunService:IsServer() then
		remote.OnServerEvent:Connect(function(player, target: types.IncomingConnector, ...)
			--- check if the player is allowed to send this
			if not do_not_block_traffic and not traffic_check.check(player, target.host) then
				return
			end

			--- check if its a proper connector
			if not tincoming_connector(target) then return end
	
			if target.host == "server" and (target.to_vm == vm_id or target.to_vm == nil) then
				target.host = player
				fire(target, ...)
			elseif target.host ~= "server" and vm_id == MANAGER_VM then
				local to = target.host
				target.host = player
				remote:FireClient(
					to,
					target,
					...
				)
			end
		end)
	else
		remote.OnClientEvent:Connect(function(incoming: types.IncomingConnector, ...)
			-- print("receive", remote.Name, "from", incoming.host)
			if tincoming_connector(incoming) == false then return end
			if incoming.to_vm ~= vm_id and incoming.to_vm ~= nil then return end
			traffic_check._whitelist(local_host, incoming.host)

			fire(incoming, ...)
		end)
	end

	remote:WaitForChild("actor").Event:Connect(function(incoming: types.IncomingConnector, ...)
		if incoming.to_vm ~= vm_id and incoming.to_vm ~= nil then return end
		fire(incoming, ...)
	end)

	return (event :: any) :: types.NetEvent<T...>
end

return {
	create_event = create_event,
	local_host = local_host
}
