local jecs = require("@jecs")
local OB = require("@modules/OB/module")

local ct = {
	Transform = jecs.component() :: jecs.Id<CFrame>,
	PivotTo = jecs.component() :: jecs.Id<CFrame>,
	TRANSFORM_PREDICTED = jecs.tag(),
	Renderable = jecs.component() :: jecs.Id<Instance>
}

local function main(world: jecs.World)
	local function pivots_added(entity: jecs.Entity)
		local dst: CFrame?, model: Instance? = world:get(entity, ct.PivotTo, ct.Renderable)
		if dst == nil then
			return
		end

		world:set(entity, ct.Transform, dst)
		world:remove(entity, ct.PivotTo)
		;(model :: Model):PivotTo(dst)
	end

	local authoritative_transforms = world
		:query(ct.Transform, ct.Renderable)
		:without(ct.TRANSFORM_PREDICTED)
		:cached()

	local predicted_transforms = world
	    :query(ct.Transform, ct.Renderable)
		:with(ct.TRANSFORM_PREDICTED)
		:cached()

	OB.observer(world:query(ct.PivotTo, ct.Renderable), pivots_added)


	return function()
		for entity, transform, renderable in authoritative_transforms do
			local model = renderable :: Model
			local primarypart = model.PrimaryPart
			if primarypart == nil or primarypart.CFrame == transform then
				continue
			end

			primarypart.CFrame = transform
		end

		for entity, transform, model in predicted_transforms do
			local primarypart = (model :: Model).PrimaryPart
			if primarypart == nil then
				continue
			end

			local cframe = primarypart.CFrame

			if (transform.Position - cframe.Position).Magnitude < 0.1 then
				continue
			end

			world:set(entity, ct.Transform, cframe)
		end
	end
end

local world = jecs.world()

local entity = world:entity()
local part = Instance.new("Part")
part.Anchored = true
part.Parent = workspace
world:set(entity, ct.Renderable, part)
world:set(entity, ct.PivotTo, CFrame.new())

local system = main(world)
system(1/60)
