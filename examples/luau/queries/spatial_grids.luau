local jecs = require("@jecs")
local pair = jecs.pair
local ChildOf = jecs.ChildOf
local __ = jecs.Wildcard
local Name = jecs.Name
local world = jecs.world()

local Voxel = world:component() :: jecs.Id
local Position = world:component() :: jecs.Id<vector>
local Perception = world:component() :: jecs.Id<{
	range: number,
	fov: number,
	dir: vector,
}>
type part = {
	Position: vector
}
local PrimaryPart = world:component() :: jecs.Id<part>

local local_player = {
	Character = {
		PrimaryPart = {
			Position = vector.create(50, 0, 30)
		}
	}
}
local workspace = {
	CurrentCamera = {
		CFrame = {
			LookVector = vector.create(0, 0, -1)
		}
	}
}

local function distance(a: vector, b: vector)
	return vector.magnitude((b - a))
end

local function is_in_fov(a: vector, b: vector, forward_dir: vector, fov_angle: number)
	local to_target = b - a

	local forward_xz = vector.normalize(vector.create(forward_dir.x, 0, forward_dir.z))
	local to_target_xz = vector.normalize(vector.create(to_target.x, 0, to_target.z))

	local angle_to_target = math.deg(math.atan2(to_target_xz.z, to_target_xz.x))
	local forward_angle = math.deg(math.atan2(forward_xz.z, forward_xz.z))

	local angle_difference = math.abs(forward_angle - angle_to_target)

	if angle_difference > 180 then
		angle_difference = 360 - angle_difference
	end

	return angle_difference <= (fov_angle / 2)
end

local map = {}
local grid = 50

local function add_to_voxel(source: jecs.Entity, position: vector, prev_voxel_id: jecs.Entity?)
	local hash = position // grid
	local voxel_id = map[hash]
	if not voxel_id then
		voxel_id = world:entity()
		world:add(voxel_id, Voxel)
		world:set(voxel_id, Position, hash)
		map[hash] = voxel_id
	end
	if prev_voxel_id ~= nil then
		world:remove(source, pair(ChildOf, prev_voxel_id))
	end
	world:add(source, pair(ChildOf, voxel_id))
end

local function reconcile_client_owned_assembly_to_voxel(dt: number)
	for e, part, position in world:query(PrimaryPart, Position) do
		local p = part.Position
		if p ~= position then
			world:set(e, Position, p)
			local voxel_id = world:target(e, ChildOf, 0)
			if map[p // grid] == voxel_id then
				continue
			end

			add_to_voxel(e, p, voxel_id)
		end
	end
end

local function update_camera_direction(dt: number)
	for _, perception in world:query(Perception) do
		perception.dir = workspace.CurrentCamera.CFrame.LookVector
	end
end

local function perceive_enemies(dt: number)
	local it = world:query(Perception, Position, PrimaryPart):iter()
	-- There is only going to be one entity matching the query
	local e, self_perception, self_position, self_primary_part = it()

	local voxel_id = map[self_primary_part.Position // grid]
	local nearby_entities_query = world:query(Position, pair(ChildOf, voxel_id))

	for enemy, target_position in nearby_entities_query do
		if distance(self_position, target_position) > self_perception.range then
			continue
		end

		if is_in_fov(self_position, target_position, self_perception.dir, self_perception.fov) then
			local p = target_position
			print(`Entity {world:get(e, Name)} can see target {world:get(enemy, Name)} at ({p.x}, {p.y}, {p.z})`)
		end
	end
end

local player = world:entity()
world:set(player, Perception, {
	range = 200,
	fov = 90,
	dir = vector.create(1, 0, 0),
})
world:set(player, Name, "LocalPlayer")
local primary_part = local_player.Character.PrimaryPart
world:set(player, PrimaryPart, primary_part)
world:set(player, Position, vector.zero)

local enemy = world:entity()
world:set(enemy, Name, "Enemy $1")
world:set(enemy, Position, vector.create(50, 0, 20))

add_to_voxel(player, primary_part.Position)
add_to_voxel(enemy, assert(world:get(enemy, Position)))

local dt = 1 / 60
reconcile_client_owned_assembly_to_voxel(dt)
update_camera_direction(dt)
perceive_enemies(dt)

-- Output:
--  LocalPlayer can see target Enemy $1
