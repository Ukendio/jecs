--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.ecs)
local types = require("./types")

local Networked = jecs.tag()
local NetworkedPair = jecs.tag()

local InstanceMapping = jecs.component() :: jecs.Id<Instance>
jecs.meta(InstanceMapping, jecs.OnAdd, function(component)
	jecs.meta(component, jecs.OnAdd, function(entity, _, instance)
		if RunService:IsServer() then
			instance:SetAttribute("entity_server")
		else
			instance:SetAttribute("entity_client")
		end
	end)
end)

local function networked_id(ct)
	jecs.meta(ct, Networked)
	return ct
end
local function networked_pair(ct)
	jecs.meta(ct, NetworkedPair)
	return ct
end
local function instance_mapping_id(ct)
	jecs.meta(ct, InstanceMapping)
	return ct
end

local Renderable = jecs.component() :: types.Id<Instance>
local Poison = jecs.component() :: types.Id<number>
local Health = jecs.component() :: types.Id<number>
local Player = jecs.component() :: types.Id<Player>
local Debuff = jecs.tag() :: types.Entity
local Lifetime = jecs.component() :: types.Id<{
	duration: number,
	created: number
}>
local Destroy = jecs.tag()

local components = {
	Renderable = networked_id(instance_mapping_id(Renderable)),
	Player = networked_id(Player),
	Poison = networked_id(Poison),
	Health = networked_id(Health),
	Lifetime = networked_id(Lifetime),
	Debuff = networked_id(Debuff),
	Destroy = networked_id(Destroy),

	-- We have to define that some builtin IDs can also be networked
	ChildOf = networked_pair(jecs.ChildOf),

	Networked = Networked,
	NetworkedPair = NetworkedPair,
}

for name, component in components :: {[string]: types.Id<any> } do
	jecs.meta(component, jecs.Name, name)
end

return components
