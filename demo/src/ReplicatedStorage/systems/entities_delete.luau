
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local types = require(ReplicatedStorage.types)
local ct = require(ReplicatedStorage.components)

local function entities_delete(world: types.World, dt: number)
	for e in world:each(ct.Destroy) do
		world:delete(e)
	end
end

return entities_delete
