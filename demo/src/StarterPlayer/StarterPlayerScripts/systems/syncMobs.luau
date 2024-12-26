local ReplicatedStorage = game:GetService("ReplicatedStorage")
local blink = require(ReplicatedStorage.net)
local std = ReplicatedStorage.std
local ref = require(std.ref)
local world = require(std.world)
local cts = require(std.components)

local function syncMobs()
	for _, id, cf, vel in blink.SpawnMob.Iter() do
		local part = Instance.new("Part")
		part.Size = Vector3.one * 5
		part.BrickColor = BrickColor.Red()
		part.Anchored = true
		local model = Instance.new("Model")
		model.PrimaryPart = part
		part.Parent = model
		model.Parent = workspace

		local e = ref("server-" .. tostring(id))
		world:set(e, cts.Transform, { new = cf, old = cf })
		world:set(e, cts.Velocity, vel)
		world:set(e, cts.Model, model)
		world:add(e, cts.Mob)
	end
end

local scheduler = require(std.scheduler)
scheduler.SYSTEM(syncMobs)

return 0

