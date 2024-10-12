local ReplicatedStorage = game:GetService("ReplicatedStorage")
local blink = require(ReplicatedStorage.net)
local std = require(ReplicatedStorage.std)
local world = std.world
local ref = std.ref

local cts = std.components

local Model = cts.Model
local Transform = cts.Transform

local function move(dt: number)
	for _, transform, model in world:query(Transform, Model):iter() do
		local cf = transform.new
		if cf ~= transform.old then
			local origo = model.PrimaryPart.CFrame
			model.PrimaryPart.CFrame = origo:Lerp(cf, 1)
			transform.old = cf
		end
	end
end

local function syncTransforms()
	for _, id, cf in blink.UpdateTransform.Iter() do
		local e = ref("server-" .. id)
		local transform = e:get(cts.Transform)
		if not transform then
			continue
		end
		transform.new = cf
	end
end

return function(scheduler: std.Scheduler)
	local phases = scheduler.phases
	local system_new = scheduler.systems.new
	system_new(move, phases.Heartbeat)
	system_new(syncTransforms, phases.RenderStepped)
end
