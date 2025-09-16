local jecs = require("@jecs")

local world = jecs.world()
local Physics = world:entity()
local DamagableByPlayer = world:entity()
local Mob = world:entity()
local Player = world:entity()
local Goblin = world:entity()

local Position = world:component() :: jecs.Id<vector>
local Velocity = world:component() :: jecs.Id<vector>
local Acceleration = world:component() :: jecs.Id<vector>

local Health = world:component() :: jecs.Id<number>
local MaxHealth = world:component() :: jecs.Id<number>

local TouchHurts = world:entity()


local function setup_player(entity: jecs.Entity)
	jecs.bulk_insert(world, entity,
		{
			MaxHealth,
			Health,
			Position,
			Acceleration,
			Velocity,
			Player,
			Mob,
			DamagableByPlayer,
			Physics,
		},
		{
			100,
			100,
			vector.zero,
			vector.zero,
			vector.zero,
		}
	)
end
local function setup_goblin(entity: jecs.Entity)
	jecs.bulk_insert(world, entity,
		{
			MaxHealth,
			Health,
			Position,
			Acceleration,
			Velocity,
			Mob,
			Goblin,
			DamagableByPlayer,
			Physics
		},
		{
			200,
			200,
			vector.zero,
			vector.zero,
			vector.zero,
		}
	)
end

local function setup_wood_spikes(entity: jecs.Entity)
	jecs.bulk_insert(world, entity,
		{
			Position,
			TouchHurts,
		},
		{
			vector.normalize(vector.create(math.random(), math.random(), math.random()))
		}
	)
end

type EntityKind = "player" | "goblin" | "ogre" | "big_boss_goblin" | "wood_spikes"

local function exhaustive(x: never?)
	error(x)
end

local function entity_create(kind: EntityKind)
	local new_entity = world:entity()
	if kind == "player" then
		setup_player(new_entity)
	elseif kind == "big_boss_goblin" then
		setup_goblin(new_entity)
	elseif kind == "goblin" then
		setup_goblin(new_entity)
	elseif kind == "wood_spikes" then
		setup_wood_spikes(new_entity)
	elseif kind == "ogre" then
		setup_goblin(new_entity)
	else
		exhaustive(kind)
	end
end

for i = 1, 10 do
	entity_create("player")
end

for i = 1, 100 do
	entity_create("goblin")
end

for i = 1, 1000 do
	entity_create("wood_spikes")
end

local it = 0

local has_physics = world:query(Position, Velocity, Acceleration):cached()
local touch_hurts_against_mobs = world:query(Position):with(TouchHurts):cached()
local damageable_mobs = world:query(Position, Health):with(DamagableByPlayer):cached()
local players = world:query(Position):with(Player):cached()
local dying_mobs = world:query(Health):cached()

local function physics(dt: number)
	for entity, pos, vel, acc in has_physics do
		vel += acc * dt
		pos += vel * dt
		acc = vector.zero
		world:set(entity, Velocity, vel)
		world:set(entity, Position, vel)
		world:set(entity, Acceleration, vel)
		it+=1
	end
end

local function touch_hurts_mobs()
	for _, arch2 in damageable_mobs:archetypes() do
		local against_positions = arch2.columns_map[Position]
		local against_health = arch2.columns_map[Health]
		for row2, health in against_health do
			it += 1
			local against_pos = against_positions[row2]
			for _, arch1 in touch_hurts_against_mobs:archetypes() do
				local entity_positions = arch1.columns_map[Position]
				for row, entity_pos in entity_positions do
					it += 1
					if vector.magnitude(against_pos - entity_pos) < 5  then
						continue
					end
					health -= 1
				end
			end

			against_health[row2] = health
		end
	end
end

local function players_damage_mobs()
	for _, arch2 in damageable_mobs:archetypes() do
		local against_health = arch2.columns_map[Health]
		for row2, health in against_health do
			it += 1
			for _, arch1 in players:archetypes() do
				local entity_positions = arch1.columns_map[Position]
				for row, entity_pos in entity_positions do
					it += 1
					health -= 1
				end
			end

			against_health[row2] = health
		end
	end
end

local function mobs_die()
	for entity, health in dying_mobs do
		it += 1
		if health <= 0 then
			world:delete(entity)
		end
	end
end

local function update(dt: number, tick: number)
	it = 0
	physics(dt)

	touch_hurts_mobs(dt)

	players_damage_mobs(dt)

	mobs_die(dt)

	if (tick % 10)==0 then
		entity_create("goblin")
		entity_create("player")
	end
end

-- 0.062 seconds for 1000 frames.
for i = 1, 1000 do
	update(1/60, i)
end
