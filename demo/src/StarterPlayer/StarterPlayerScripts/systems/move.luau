local ReplicatedStorage = game:GetService("ReplicatedStorage")
local blink = require(ReplicatedStorage.net)
local std = ReplicatedStorage.std
local world = require(std.world)
local ref = require(std.ref)

local cts = require(std.components)

local Model = cts.Model
local Transform = cts.Transform

local moving_models = world:query(Transform, Model):cached()
local function move(dt: number)
	for _, transform, model in moving_models do
		local cf = transform.new
		if cf ~= transform.old then
			local part = model.PrimaryPart :: BasePart
			local origo = part.CFrame
			part.CFrame = origo:Lerp(cf, 1)
			transform.old = cf
		end
	end
end

local function syncTransforms()
	for _, id, cf in blink.UpdateTransform.Iter() do
		local e = ref("server-" .. tostring(id))
		local transform = world:get(e, Transform)
		if not transform then
			continue
		end
		transform.new = cf
	end
end

local scheduler = require(std.scheduler)

scheduler.SYSTEM(move)
scheduler.SYSTEM(syncTransforms)

return 0