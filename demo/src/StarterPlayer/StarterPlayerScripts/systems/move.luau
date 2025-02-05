local ReplicatedStorage = game:GetService("ReplicatedStorage")
local blink = require(ReplicatedStorage.net)
local std = ReplicatedStorage.std
local world = require(std.world)
local ref = require(std.ref)

local cts = require(std.components)

local Model = cts.Model
local Transform = cts.Transform

local moved_models = world:query(Model, Transform):cached()
local updated_models = {}
local i = 0
local function processed(n)
	i += 1
	if i > n then
		i = 0
		return true
	end
	return false
end

local function move(dt: number)
	for entity, model in moved_models do
		if updated_models[entity] then
			updated_models[entity] = nil
			model.PrimaryPart.CFrame = transform
		end
	end
end

local function syncTransforms()
	for _, id, cf in blink.UpdateTransform.Iter() do
		local e = ref("server-" .. tostring(id))
		world:set(e, Transform, cf)
		moved_models[e] = true
	end
end

local scheduler = require(std.scheduler)

scheduler.SYSTEM(move)
scheduler.SYSTEM(syncTransforms)

return 0
