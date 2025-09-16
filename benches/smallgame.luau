local gamestate = {
	entities = {} :: { Entity },
	entity_top_count = 0,
	entity_id_gen = 0
}
for i = 1, 2048 do
	gamestate.entities[i] = {} :: Entity
end

type EntityKind = "player" | "goblin" | "ogre" | "big_boss_goblin" | "wood_spikes"
type EntityHandle = {
	index: number,
	id: number
}
type Entity = {
	allocated: boolean,
	handle: EntityHandle,
	kind: EntityKind,

	has_physics: boolean,
	damagable_by_player: boolean,
	is_mob: boolean,
	blocks_mobs: boolean,

	position: vector,
	velocity: vector,
	acceleration: vector,
	hitbox: vector,
	hit_cooldown_end_time: number,
	health: number,
	next_attack_time: number,
	sprite_id: number,
	current_animation_frame: number,

	update: (Entity) -> (),
	draw: (Entity) -> (),
	max_health: number,

}

local function exhaustive(x: never?)
	error(x)
end

local function entity_delete(entity: Entity)
	table.clear(entity::any)
end

local it = 0
local it_qualified = 0
local function setup_player(entity: Entity)
	entity.kind = "player"
	entity.is_mob = true
	entity.damagable_by_player = true
	entity.max_health = 100
	entity.health = 100
	entity.has_physics = true
	entity.acceleration = vector.zero
	entity.velocity = vector.zero
	entity.position = vector.zero

	entity.update = function()
		entity.health = entity.max_health
		entity.acceleration += vector.create(
			math.random(1, 5),
			math.random(1, 5),
			math.random(1, 5)
		)
		if entity.health <= 0 then
			entity_delete(entity)
		end

		for _, against in gamestate.entities do
			it += 1
			if not against.allocated then
				continue
			end
			if not against.damagable_by_player then
				continue
			end
			it_qualified += 1
			against.health -= 1

		end
	end
end
local function setup_goblin(entity: Entity)
	entity.kind = "goblin"
	entity.is_mob = true
	entity.damagable_by_player = true
	entity.max_health = 200
	entity.health = 200
	entity.has_physics = true
	entity.acceleration = vector.zero
	entity.velocity = vector.zero
	entity.position = vector.zero

	entity.update = function()
		entity.acceleration += vector.normalize(vector.create(math.random(), math.random(), math.random()))
		if entity.health <= 0 then
			entity_delete(entity)
		end
	end
end

local function setup_wood_spikes(entity: Entity)
	entity.kind = "wood_spikes"
	entity.is_mob = false
	entity.damagable_by_player = false
	entity.position = vector.create(
		math.random(1, 5),
		math.random(1, 5),
		math.random(1, 5)
	)

	entity.update = function()
		for _, against in gamestate.entities do
			it += 1
			if not against.allocated then
				continue
			end
			if against.is_mob == false then
				continue
			end
			if vector.magnitude(against.position - entity.position) < 5 then
				continue
			end

			it_qualified += 1
			against.health -= 1
		end
	end
end

local function entity_create(kind: EntityKind): Entity
	local new_entity: Entity = nil::any
	local new_index = 0
	for index, entity in gamestate.entities do
		if entity.allocated then
			continue
		end
		new_entity = entity
		new_index = index
		break
	end

	assert(new_index ~= 0)
	gamestate.entity_top_count += 1

	new_entity.handle = {} :: EntityHandle
	new_entity.allocated = true
	gamestate.entity_id_gen += 1
	new_entity.handle.id = gamestate.entity_id_gen
	new_entity.handle.index = new_index

	gamestate.entities[new_index] = new_entity

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

	return new_entity
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

local function update(dt: number, tick: number)
	it = 0
	it_qualified = 0
	for _, entity in gamestate.entities do
		it += 1
		if not entity.allocated then
			continue
		end
		it_qualified += 1
		entity.update(entity)

		if entity.has_physics then
			entity.velocity += entity.acceleration * dt
			entity.position += entity.velocity * dt
			entity.acceleration = vector.zero
		end
	end
	if (tick % 10)==0 then
		entity_create("goblin")
		entity_create("player")
	end
end

-- 14.839 seconds for 1000 frames
for i = 1, 1000 do
	update(1/60, i)
end
