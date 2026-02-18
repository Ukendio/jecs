local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local loop = require(script.Parent.modules.loop)
local remotes = require(script.Parent.modules.remotes)
local traffic_check = require(script.Parent.modules.traffic_check)
local vm_id = require(script.Parent.modules.vm_id)
local function broadcast()
	for _, player in Players:GetPlayers() do
		if not traffic_check.can_use_jabby(player) then continue end
		remotes.new_server_registered:fire({
			host = player,
		})
	end
end

task.delay(0, broadcast)

local systems = script.systems
local loop = loop (
	`jabby-host:{
		if RunService:IsServer() then "server" else "client"
	}-vm:{vm_id}`,
	nil,
	{i = 1},

	systems.ping,
	systems.replicate_core,
	systems.replicate_scheduler,
	systems.replicate_registry,
	systems.replicate_system_watch,
	systems.mouse_pointer,
	systems.entity
)

RunService.PostSimulation:Connect(loop)

return {

	broadcast = broadcast

}