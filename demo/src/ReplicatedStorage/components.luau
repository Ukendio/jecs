local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.ecs)
local types = require("./types")

local Networked = jecs.tag()
local NetworkedPair = jecs.tag()

local Renderable = jecs.component() :: jecs.Id<Instance>
jecs.meta(Renderable, Networked)


local Poison = jecs.component() :: jecs.Id<number>
jecs.meta(Poison, Networked)

local Health = jecs.component() :: jecs.Id<number>
jecs.meta(Health, Networked)

local Player = jecs.component() :: jecs.Id<Player>
jecs.meta(Player, Networked)


local components = {
	Renderable = Renderable,
	Player = Player,
	Poison = Poison,
	Health = Health,

	Networked = Networked,
	NetworkedPair = NetworkedPair,
}

for name, component in components do
	jecs.meta(component, jecs.Name, name)
end

return components
