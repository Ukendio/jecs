local collect = require("../../ReplicatedStorage/collect")
local types = require("../../ReplicatedStorage/types")
local ct = require("../../ReplicatedStorage/components")
local Players = game:GetService("Players")

local player_added = collect(Players.PlayerAdded)
return function(world: types.World, dt: number)
	for player in player_added do
		local entity = world:entity()
		world:set(entity, ct.Player, player)
	end

	for entity, player in world:query(ct.Player):without(ct.Renderable) do
		local character = player.Character
		if character then
		if not character.Parent then
			world:set(entity, ct.Renderable, character)
		end
	end
end
