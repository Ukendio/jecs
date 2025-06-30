local jecs = require("@jecs")

local testkit = require("@testkit")
local BENCH, START = testkit.benchmark()
local __ = jecs.Wildcard
local ECS_ID, ECS_GENERATION = jecs.ECS_ID, jecs.ECS_GENERATION
local ECS_GENERATION_INC = jecs.ECS_GENERATION_INC
local IS_PAIR = jecs.IS_PAIR
local pair = jecs.pair
local ecs_pair_first = jecs.pair_first
local ecs_pair_second = jecs.pair_second
local ChildOf = jecs.ChildOf

local it = testkit.test()
local TEST, CASE = it.TEST, it.CASE
local CHECK, FINISH = it.CHECK, it.FINISH
local SKIP, FOCUS = it.SKIP, it.FOCUS
local CHECK_EXPECT_ERR = it.CHECK_EXPECT_ERR

type World = jecs.World
type Entity<T=nil> = jecs.Entity<T>
type Id<T=unknown> = jecs.Id<T>

local entity_visualiser = require("@tools/entity_visualiser")
local dwi = entity_visualiser.stringify

TEST("repro", function()


end)

TEST("bulk", function()
	local world = jecs.world()
	local A = world:component()
	local B = world:component()
	local C = world:component()

	local D = world:component()
	local E = world:entity()
	local F = world:component()

	local e = world:entity()
	local r = jecs.entity_index_try_get(world.entity_index, e)
	jecs.bulk_insert(world, e, { A, B, C }, { 1, 2, 3 })
	CHECK(world:get(e, A) == 1)
	CHECK(world:get(e, B) == 2)
	CHECK(world:get(e, C) == 3)

	jecs.bulk_insert(world, e,
		{ D, E, F },
		{ 4, nil, 5 }
	)
	CHECK(world:get(e, A) == 1)
	CHECK(world:get(e, B) == 2)
	CHECK(world:get(e, C) == 3)

	CHECK(world:get(e, D) == 4)
	CHECK(world:get(e, E) == nil and world:has(e, E))
	CHECK(world:get(e, F) == 5)

	jecs.bulk_insert(world, e,
		{ A, D, E, F, C },
		{ 10, 40, nil, 50, 30 }
	)

	CHECK(world:get(e, A) == 10)
	CHECK(world:get(e, B) == 2)
	CHECK(world:get(e, C) == 30)
	CHECK(world:get(e, D) == 40)
	CHECK(world:get(e, E) == nil and world:has(e, E))
	CHECK(world:get(e, F) == 50)

	local G = world:component()
	world:set(e, G, 100)

	CHECK(world:get(e, A) == 10)
	CHECK(world:get(e, B) == 2)
	CHECK(world:get(e, C) == 30)
	CHECK(world:get(e, D) == 40)
	CHECK(world:get(e, E) == nil and world:has(e, E))
	CHECK(world:get(e, F) == 50)
	CHECK(world:get(e, G) == 100)

	world:remove(e, B)

	CHECK(world:get(e, A) == 10)
	CHECK(world:has(e, B) == false)
	CHECK(world:get(e, C) == 30)
	CHECK(world:get(e, D) == 40)
	CHECK(world:get(e, E) == nil and world:has(e, E))
	CHECK(world:get(e, F) == 50)
	CHECK(world:get(e, G) == 100)

	jecs.bulk_remove(world, e, { A, B, C, D })

	CHECK(world:has(e, A) == false)
	CHECK(world:has(e, B) == false)
	CHECK(world:has(e, C) == false)
	CHECK(world:has(e, D) == false)
	CHECK(world:get(e, E) == nil and world:has(e, E))
	CHECK(world:get(e, F) == 50)
	CHECK(world:get(e, G) == 100)

	jecs.bulk_insert(world, e, { D, G }, { 999, 1 })

	CHECK(world:has(e, A) == false)
	CHECK(world:has(e, B) == false)
	CHECK(world:has(e, C) == false)
	CHECK(world:get(e, D) == 999)
	CHECK(world:get(e, E) == nil and world:has(e, E))
	CHECK(world:get(e, F) == 50)
	CHECK(world:get(e, G) == 1)

	jecs.bulk_remove(world, e, { A, B, C, D, E, F, G })

	CHECK(world:has(e, A) == false)
	CHECK(world:has(e, B) == false)
	CHECK(world:has(e, C) == false)
	CHECK(world:has(e, D) == false)
	CHECK(world:has(e, E) == false)
	CHECK(world:has(e, F) == false)
	CHECK(world:has(e, G) == false)
end)

TEST("repro", function()
	local Model = jecs.component()
	local Relation = jecs.component()
	local Relation2 = jecs.component()

	local world = jecs.world()

	local e1 = world:entity()
	world:set(e1, Model, 2)

	local e2 = world:entity()
	world:set(e2, Model, 2)
	world:set(e2, jecs.pair(Relation, e1), 5)

	local e3 = world:entity()
	world:set(e3, Model, 2)
	world:set(e3, jecs.pair(Relation, e1), 5)

	world:delete(e1)

	for _ in world:query(Model) do end
	jecs.ECS_META_RESET()
end)

TEST("world:add()", function()
	do CASE "idempotent"
		local world = jecs.world()
		local d = dwi(world)
		local _1, _2 = world:component(), world:component()

		local e = world:entity()
		world:add(e, _1)
		world:add(e, _2)

		world:add(e, _2) -- should have 0 effects
		CHECK(d.archetype(e) == "1_2")
	end

	do CASE("archetype move")
		local world = jecs.world()

		local d = dwi(world)

		local _1 = world:component()
		local e = world:entity()
		-- An entity starts without an archetype or row
		-- should therefore not need to copy over data
		CHECK(d.tbl(e) == nil)
		CHECK(d.row(e) == nil)

		local archetypes = #world.archetypes
		-- This should create a new archetype
		world:add(e, _1)
		CHECK(#world.archetypes == archetypes + 1)

		CHECK(d.archetype(e) == "1")
		CHECK(d.tbl(e))
	end
end)

TEST("world:children()", function()
	local world = jecs.world()
	local C = jecs.component()
	local T = jecs.tag()

	local e1 = world:entity()
	world:set(e1, C, true)

	local e2 = world:entity()

	world:add(e2, T)
	world:add(e2, pair(ChildOf, e1))

	local e3 = world:entity()
	world:add(e3, pair(ChildOf, e1))

	local count = 0
	for entity in world:children(e1) do
		count += 1
		if entity == e2 or entity == e3 then
			CHECK(true)
			continue
		end
		CHECK(false)
	end
	CHECK(count == 2)

	world:remove(e2, pair(ChildOf, e1))

	count = 0
	for entity in world:children(e1) do
		count += 1
	end

	CHECK(count == 1)

	jecs.ECS_META_RESET()
end)

TEST("world:clear()", function()
	do CASE "should remove its components"
		local world = jecs.world()
		local A = world:component()
		local B = world:component()

		local e = world:entity()
		local e1 = world:entity()
		local _e2 = world:entity()

		world:set(e, A, true)
		world:set(e, B, true)

		world:set(e1, A, true)
		world:set(e1, B, true)

		CHECK(world:get(e, A))
		CHECK(world:get(e, B))

		world:clear(A)
		CHECK(world:get(e, A) == nil)
		CHECK(world:get(e, B))
		CHECK(world:get(e1, A) == nil)
		CHECK(world:get(e1, B))
	end

	do CASE "remove cleared ID from entities"
		local world = jecs.world()
		local A = world:component()
		local B = world:component()
		local C = world:component()

		do
			local id1 = world:entity()
			local id2 = world:entity()
			local id3 = world:entity()

			world:set(id1, A, true)

			world:set(id2, A, true)
			world:set(id2, B, true)

			world:set(id3, A, true)
			world:set(id3, B, true)
			world:set(id3, C, true)

			world:clear(A)

			CHECK(not world:has(id1, A))
			CHECK(not world:has(id2, A))
			CHECK(not world:has(id3, A))

			CHECK(world:has(id2, B))
			CHECK(world:has(id3, B, C))

			world:clear(C)

			CHECK(world:has(id2, B))
			CHECK(world:has(id3, B))

			CHECK(world:contains(A))
			CHECK(world:contains(C))
			CHECK(world:has(A, jecs.Component))
			CHECK(world:has(B, jecs.Component))
		end

		do
			local id1 = world:entity()
			local id2 = world:entity()
			local id3 = world:entity()

			local tgt = world:entity()

			world:add(id1, pair(A, tgt))
			world:add(id1, pair(B, tgt))
			world:add(id1, pair(C, tgt))

			world:add(id2, pair(A, tgt))
			world:add(id2, pair(B, tgt))
			world:add(id2, pair(C, tgt))

			world:add(id3, pair(A, tgt))
			world:add(id3, pair(B, tgt))
			world:add(id3, pair(C, tgt))

			world:clear(B)
			CHECK(world:has(id1, pair(A, tgt), pair(C, tgt)))
			CHECK(not world:has(id1, pair(B, tgt)))
			CHECK(world:has(id2, pair(A, tgt), pair(C, tgt)))
			CHECK(not world:has(id1, pair(B, tgt)))
			CHECK(world:has(id3, pair(A, tgt), pair(C, tgt)))

		end

	end
end)

TEST("world:component()", function()
	do CASE "allow IDs to be registered"
		local A = jecs.component()
		local B = jecs.component()

		local world = jecs.world()
		local C = world:component()
		CHECK((A :: any) == 1)
		CHECK((B :: any) == 2)
		CHECK((C :: any) == 3)

		local e = world:entity()

		world:set(e, A, "foo")
		world:set(e, B, "foo")
		world:set(e, C, "foo")

		CHECK(world:has(e, A, B, C))

		jecs.ECS_META_RESET() -- Reset the ECS metadata because they may have side effects
	end
	do CASE "only components should have EcsComponent trait"
		local world = jecs.world()
		local A = world:component()
		local e = world:entity()

		CHECK(world:has(A, jecs.Component))
		CHECK(not world:has(e, jecs.Component))
	end

	do CASE "tag"
		local world = jecs.world()
		local A = world:component()
		local B = world:entity()
		local C = world:entity()
		local e = world:entity()
		world:set(e, A, "test")
		world:add(e, B)
		CHECK_EXPECT_ERR(function()
			world:set(e, C, 11 :: any)
		end)

		CHECK(world:has(e, A))
		CHECK(world:get(e, A) == "test")
		CHECK(world:get(e, B) == nil)
		CHECK(world:get(e, C) == nil)
	end
end)

TEST("world:contains()", function()

	local tag = jecs.tag()
	local world = jecs.world()
	local id = world:entity()
	CHECK(world:contains(id))

	do
		CASE("should not exist after delete")
		world:delete(id)
		CHECK(not world:contains(id))
	end


	CHECK(world:contains(tag))
	jecs.ECS_META_RESET()
end)

TEST("world:delete()", function()
	do CASE "pair(OnDelete, Delete)"
	    local world = jecs.world()
	    local ct = world:component()
	    world:add(ct, jecs.pair(jecs.OnDelete, jecs.Delete))

	    local e1 = world:entity()
	    local e2 = world:entity()

	    local dummy = world:entity()

	    world:add(e1, ct)
	    world:add(e2, jecs.pair(ct, dummy))

	    world:delete(dummy)

	    CHECK(world:contains(e2))

	    world:delete(ct)

	    CHECK(not world:contains(e1))
	end

	do CASE "pair(OnDeleteTarget, Delete)"
	    local world = jecs.world()
	    local ct = world:component()
	    world:add(ct, jecs.pair(jecs.OnDeleteTarget, jecs.Delete))

	    local e1 = world:entity()
	    local e2 = world:entity()

	    local dummy = world:entity()

	    world:add(e1, ct)

	    world:add(e2, jecs.pair(ct, dummy))

	    world:delete(dummy)

	    CHECK(not world:contains(e2))

	    world:delete(ct)

	    CHECK(world:contains(e1))
	end
	do CASE "remove (*, R) pairs when relationship is invalidated"
		local world = jecs.world()
		local e1 = world:entity()
		local e2 = world:entity()

		local A = world:component()
		local B = world:component()
		local C = world:component()

		world:add(e1, pair(e2, A))
		world:add(e1, B) -- Some stable component that should not be removed in the process
		world:add(e1, pair(e2, C))
		world:delete(e2)

		CHECK(not world:contains(e2))
		CHECK(not world:has(e1, pair(e2, A)))
		CHECK(world:has(e1, B))
		CHECK(not world:has(e1, pair(e2, C)))
		CHECK(world:contains(e1))
	end
	do CASE "remove pair when relationship is deleted"
		local world = jecs.world()
		local e1 = world:entity()
		local e2 = world:entity()

		local A = world:component()
		local B = world:component()
		local C = world:component()

		world:add(e1, pair(A, e2))
		world:add(e1, pair(B, e2))
		world:add(e1, pair(C, e2))
		world:delete(A)

		CHECK(not world:has(e1, pair(A, e2)))
		CHECK(world:has(e1, pair(B, e2)))
		CHECK(world:has(e1, pair(C, e2)))
	end

	do CASE "invoke OnRemove hook on all components of deleted entity"
		local world = jecs.world()

		local e1 = world:entity()
		local e2 = world:entity()

		local Stable = world:component()
		world:set(Stable, jecs.OnRemove, function(e)
			CHECK(e == e1)
		end)

		world:set(e1, Stable, true)
		world:set(e2, Stable, true)

		world:delete(e1)
	end

	do CASE "invoke OnRemove hook on relationship if target was deleted"
		local world = jecs.world()
		local pair = jecs.pair

		local Relation = world:entity()
		local A = world:entity()
		local B = world:entity()

		world:add(Relation, pair(jecs.OnDeleteTarget, jecs.Delete))

		local entity = world:entity()

		local called = false
		world:set(A, jecs.OnRemove, function(e)
			called = true
		end)

		world:add(entity, A)
		world:add(entity, pair(Relation, B))

		world:delete(B)

		CHECK(called)
	end

	do CASE "delete recycled entity id used as component"
		local world = jecs.world()
		local id = world:entity()
		world:add(id, jecs.Component)

		local e = world:entity()
		world:set(e, id, 1)
		CHECK(world:get(e, id) == 1)
		world:delete(id)
		local recycled = world:entity()
		world:add(recycled, jecs.Component)
		world:set(e, recycled, 1)
		CHECK(world:has(recycled, jecs.Component))
		CHECK(world:get(e, recycled) == 1)
	end
	do CASE "bug: Empty entity does not respect cleanup policy"
		local world = jecs.world()
		local parent = world:entity()
		local tag = world:entity()

		local child = world:entity()
		world:add(child, jecs.pair(jecs.ChildOf, parent))
		world:delete(parent)

		CHECK(not world:contains(parent))
		CHECK(not world:contains(child))

		local entity = world:entity()
		world:add(entity, tag)
		world:delete(tag)
		CHECK(world:contains(entity))
		CHECK(not world:contains(tag))
		CHECK(not world:has(entity, tag)) -- => true
	end

	do CASE "should allow deleting components"
		local world = jecs.world()

		local Health = world:component()
		local Poison = world:component()

		local id = world:entity()
		world:set(id, Poison, 5)
		world:set(id, Health, 50)
		local id1 = world:entity()
		world:set(id1, Poison, 500)
		world:set(id1, Health, 50)

		world:delete(id)
		CHECK(not world:contains(id))
		CHECK(world:get(id, Poison) == nil)
		CHECK(world:get(id, Health) == nil)

		CHECK(world:get(id1, Poison) == 500)
		CHECK(world:get(id1, Health) == 50)
	end

	do CASE "delete entities using another Entity as component with Delete cleanup action"
		local world = jecs.world()

		local Health = world:entity()
		world:add(Health, pair(jecs.OnDelete, jecs.Delete))
		local Poison = world:component()

		local id = world:entity()
		world:set(id, Poison, 5)
		CHECK_EXPECT_ERR(function()
			world:set(id, Health, 50 :: any)
		end)
		local id1 = world:entity()
		world:set(id1, Poison, 500)
		CHECK_EXPECT_ERR(function()
			world:set(id1, Health, 50 :: any)
		end)

		CHECK(world:has(id, Poison, Health))
		CHECK(world:has(id1, Poison, Health))
		world:delete(Poison)

		CHECK(world:contains(id))
		CHECK(not world:has(id, Poison))
		CHECK(not world:has(id1, Poison))

		world:delete(Health)
		CHECK(not world:contains(id))
		CHECK(not world:contains(id1))
		CHECK(not world:has(id, Health))
		CHECK(not world:has(id1, Health))
	end


	do CASE "delete children"
		local world = jecs.world()

		local Health = world:component()
		local Poison = world:component()
		local FriendsWith = world:component()

		local e = world:entity()
		world:set(e, Poison, 5)
		world:set(e, Health, 50)

		local children = {}
		for i = 1, 10 do
			local child = world:entity()
			world:set(child, Poison, 9999)
			world:set(child, Health, 100)
			world:add(child, pair(jecs.ChildOf, e))
			table.insert(children, child)
		end

		BENCH("delete children of entity", function()
			world:delete(e)
		end)

		for i, child in children do
			CHECK(not world:contains(child))
			CHECK(not world:has(child, pair(jecs.ChildOf, e)))
			CHECK(not world:has(child, Health))
		end

		e = world:entity()

		local friends = {}
		for i = 1, 10 do
			local friend = world:entity()
			world:set(friend, Poison, 9999)
			world:set(friend, Health, 100)
			world:add(friend, pair(FriendsWith, e))
			table.insert(friends, friend)
		end

		BENCH("remove friends of entity", function()
			world:delete(e)
		end)

		for i, friend in friends do
			CHECK(not world:has(friend, pair(FriendsWith, e)))
			CHECK(world:has(friend, Health))
			CHECK(world:contains(friend))
		end
	end

	do CASE "remove deleted ID from entities"
		local world = jecs.world()
		do
			local A = world:component()
			local B = world:component()
			local C = world:component()
			local id1 = world:entity()
			local id2 = world:entity()
			local id3 = world:entity()

			world:set(id1, A, true)

			world:set(id2, A, true)
			world:set(id2, B, true)

			world:set(id3, A, true)
			world:set(id3, B, true)
			world:set(id3, C, true)

			world:delete(A)

			CHECK(not world:has(id1, A))
			CHECK(not world:has(id2, A))
			CHECK(not world:has(id3, A))

			CHECK(world:has(id2, B))
			CHECK(world:has(id3, B, C))

			world:delete(C)

			CHECK(world:has(id2, B))
			CHECK(world:has(id3, B))

			CHECK(not world:contains(A))
			CHECK(not world:contains(C))
		end

		do
			local A = world:component()
			world:add(A, pair(jecs.OnDeleteTarget, jecs.Delete))
			local B = world:component()
			local C = world:component()
			world:add(C, pair(jecs.OnDeleteTarget, jecs.Delete))

			local id1 = world:entity()
			local id2 = world:entity()
			local id3 = world:entity()

			world:set(id1, C, true)

			world:set(id2, pair(A, id1), true)
			world:set(id2, B, true)

			world:set(id3, B, true)
			world:set(id3, pair(C, id2), true)

			world:delete(id1)

			CHECK(not world:contains(id1))
			CHECK(not world:contains(id2))
			CHECK(not world:contains(id3))
		end


		do
			local A = world:component()
			local B = world:component()
			local C = world:component()
			local id1 = world:entity()
			local id2 = world:entity()
			local id3 = world:entity()


			world:set(id2, A, true)
			world:set(id2, pair(B, id1), true)

			world:set(id3, A, true)
			world:set(id3, pair(B, id1), true)
			world:set(id3, C, true)

			world:delete(id1)

			CHECK(not world:contains(id1))
			CHECK(world:contains(id2))
			CHECK(world:contains(id3))

			CHECK(world:has(id2, A))
			CHECK(world:has(id3, A, C))

			CHECK(not world:target(id2, B))
			CHECK(not world:target(id3, B))
		end
	end

	do CASE "fast delete"
		local world = jecs.world()

		local entities = {}
		local Health = world:component()
		local Poison = world:component()

		for i = 1, 100 do
			local child = world:entity()
			world:set(child, Poison, 9999)
			world:set(child, Health, 100)
			table.insert(entities, child)
		end

		BENCH("simple deletion of entity", function()
			for i = 1, START(100) do
				local e = entities[i]
				world:delete(e)
			end
		end)

		for _, entity in entities do
			CHECK(not world:contains(entity))
		end
	end

	do CASE "cycle"
		local world = jecs.world()
		local Likes = world:component()
		world:add(Likes, pair(jecs.OnDeleteTarget, jecs.Delete))
		local bob = world:entity()
		local alice = world:entity()

		world:add(bob, pair(Likes, alice))
		world:add(alice, pair(Likes, bob))

		world:delete(bob)
		CHECK(not world:contains(bob))
		CHECK(not world:contains(alice))
	end
end)

TEST("world:each()", function()
	local world = jecs.world()
	local A = world:component()
	local B = world:component()
	local C = world:component()

	local e3 = world:entity()
	local e1 = world:entity()
	local e2 = world:entity()

	world:set(e1, A, true)

	world:set(e2, A, true)
	world:set(e2, B, true)

	world:set(e3, A, true)
	world:set(e3, B, true)
	world:set(e3, C, true)

	for entity in world:each(A) do
		if entity == e1 or entity == e2 or entity == e3 then
			CHECK(true)
			continue
		end
		CHECK(false)
	end
end)

TEST("world:range()", function()
	do CASE "under range start"
		local world = jecs.world()
		world:range(400, 1000)
		local id = world:entity() :: number
		local e = world:entity(id + 5)
		CHECK(e == id + 5)
		CHECK(world:contains(e))
		local e2 = world:entity(399)
		CHECK(world:contains(e2))
		world:delete(e2)
		CHECK(not world:contains(e2))
		local e2v1 = world:entity(399) :: number
		CHECK(world:contains(e2v1))
		CHECK(ECS_ID(e2v1) == 399)
		CHECK(ECS_GENERATION(e2v1) == 0)
	end

	do CASE "over range start"
		local world = jecs.world()
		world:range(400, 1000)
		local e2 = world:entity(405)
		CHECK(world:contains(e2))
		world:delete(e2)
		CHECK(not world:contains(e2))
		local e2v1 = world:entity(405) :: number
		CHECK(world:contains(e2v1))
		CHECK(ECS_ID(e2v1) == 405)
		CHECK(ECS_GENERATION(e2v1) == 0)

		world:delete(e2v1)
		local e2v2 = world:entity(e2v1) :: number
		CHECK(ECS_ID(e2v2) == 405)
		CHECK(ECS_GENERATION(e2v2) == 0)
	end
end)

TEST("world:entity()", function()
	do CASE "desired id"
		local world = jecs.world()
		local id = world:entity() :: number
		local e = world:entity(id + 5)
		CHECK(e == id + 5)
		CHECK(world:contains(e))
		local e2 = world:entity(399)
		CHECK(world:contains(e2))
	end
	local N = 2^8

	do CASE "unique IDs"
		local world = jecs.world()
		local set = {}
		for i = 1, N do
			local e = world:entity()
			CHECK(not set[e])
			set[e] = true
		end
	end
	do CASE "generations"
		local world = jecs.world()
		local e = world:entity() :: any
		CHECK(ECS_ID(e) == 1 + jecs.Rest :: any)
		CHECK(ECS_GENERATION(e) == 0) -- 0
		e = ECS_GENERATION_INC(e)
		CHECK(ECS_GENERATION(e) == 1) -- 1
	end

	do CASE "pairs"
		local world = jecs.world()
		local _e = world:entity()
		local e2 = world:entity()
		local e3 = world:entity()

		-- Incomplete pair, must have a bit flag that notes it is a pair
		CHECK(IS_PAIR(world:entity()) == false)

		local p = pair(e2, e3)
		CHECK(IS_PAIR(p) == true)

		CHECK(ecs_pair_first(world, p) == e2)
		CHECK(ecs_pair_second(world, p) == e3)

		world:delete(e2)
		local e2v2 = world:entity() :: any
		CHECK(IS_PAIR(e2v2) == false)

		CHECK(IS_PAIR(pair(e2v2, e3) :: any) == true)
	end

	do CASE "Recycling"
		local world = jecs.world()
		local e = world:entity()
		world:delete(e)
		local e1 = world:entity()
		world:delete(e1)
		local e2 = world:entity()
		CHECK(ECS_ID(e2 :: any) :: any == e)
		CHECK(ECS_GENERATION(e2 :: any) == 2)
		CHECK(world:contains(e2))
		CHECK(not world:contains(e1))
		CHECK(not world:contains(e))
	end

	do CASE "Recycling max generation"
		local world = jecs.world()
		local pin = (jecs.Rest :: any) :: number + 1
		for i = 1, 2^16-1 do
			local e = world:entity()
			world:delete(e)
		end
		local e = world:entity() :: number
		CHECK(ECS_ID(e) == pin)
		CHECK(ECS_GENERATION(e) == 2^16-1)
		world:delete(e)
		e = world:entity() :: number
		CHECK(ECS_ID(e) == pin)
		CHECK(ECS_GENERATION(e) == 0)
	end
end)

TEST("world:has()", function()
	do CASE "should find Tag on entity"
		local world = jecs.world()

		local Tag = world:entity()

		local e = world:entity()
		world:add(e, Tag)

		CHECK(world:has(e, Tag))
	end

	do CASE "should return false when missing one tag"
		local world = jecs.world()

		local A = world:entity()
		local B = world:entity()
		local C = world:entity()
		local D = world:entity()

		local e = world:entity()
		world:add(e, A)
		world:add(e, C)
		world:add(e, D)

		CHECK(world:has(e, A, B, C, D) == false)
	end
end)

TEST("world:query()", function()
	local N = 2^8
	do CASE "cached"
		local world = jecs.world()
		local Foo = world:component()
		local Bar = world:component()
		local Baz = world:component()
		local e = world:entity()
		local q = world:query(Foo, Bar):without(Baz):cached()
		world:set(e, Foo, true)
		world:set(e, Bar, false)
		local i = 0

		local iter = 0
		for _ in q:iter() do
			iter += 1
			i=1
		end
		CHECK (iter == 1)
		CHECK(i == 1)
		for _ in q:iter() do
			i=2
		end
		CHECK(i == 2)
		for _ in q do
			i=3
		end
		CHECK(i == 3)
		for _ in q do
			i=4
		end
		CHECK(i == 4)

		CHECK(#q:archetypes() == 1)
		CHECK(not table.find(q:archetypes(), world.archetype_index[table.concat({Foo, Bar, Baz}, "_")]))
		world:delete(Foo)
		CHECK(#q:archetypes() == 0)
	end
	do CASE "multiple iter"
		local world = jecs.world()
		local A = world:component() :: jecs.Entity<string>
		local B = world:component() :: jecs.Entity<string>
		local e = world:entity()
		world:add(e, A)
		world:add(e, B)
		local q = world:query(A, B)
		local counter = 0
		for x in q:iter() do
			counter += 1
		end
		for x in q:iter() do
			counter += 1
		end
		CHECK(counter == 2)
	end
	do CASE "tag"
		local world = jecs.world()
		local A = world:entity()
		local e = world:entity()
		CHECK_EXPECT_ERR(function()
			world:set(e, A, "test" :: any)
		end)
		local count = 0
		for id, a in world:query(A) :: any do
			count += 1
			CHECK(a == nil)
		end
		CHECK(count == 1)
	end
	do CASE "pairs"
		local world = jecs.world()

		local C1 = world:component() :: jecs.Id<boolean>
		local C2 = world:component() :: jecs.Id<boolean>
		local T1 = world:entity()
		local T2 = world:entity()

		local e = world:entity()

		local C1_C2 = pair(C1, C2)
		world:set(e, C1_C2, true)
		world:set(e, pair(C1, T1), true)
		world:set(e, pair(T1, C1), true)
		CHECK_EXPECT_ERR(function()
			world:set(e, pair(T1, T2), true :: any)
		end)

		for id, a, b, c, d in world:query(pair(C1, C2), pair(C1, T1), pair(T1, C1), pair(T1, T2)):iter() do
			CHECK(a == true)
			CHECK(b == true)
			CHECK(c == true)
			CHECK(d == nil)
		end
	end
	do CASE "iterate wildcard pairs in cached query"
		local world = jecs.world()
		local pair = jecs.pair

		local Relation = world:entity()
		local Wildcard = jecs.Wildcard
		local A = world:entity()

		local relationship = pair(Relation, Wildcard)
		local query = world:query(relationship):cached()

		local entity = world:entity()

		local p = pair(Relation, A)
		CHECK(jecs.pair_first(world, p) == Relation)
		CHECK(jecs.pair_second(world, p) == A)
		world:add(entity, pair(Relation, A))

		local counter = 0
		for e in query:iter() do
			counter += 1
		end
		CHECK(counter == 1)
	end

	do CASE "iterate wildcard pairs in uncached query"
		local world = jecs.world()
		local pair = jecs.pair

		local Relation = world:entity()
		local Wildcard = jecs.Wildcard
		local A = world:entity()

		local relationship = pair(Relation, Wildcard)

		local entity = world:entity()

		world:add(entity, pair(Relation, A))

		local counter = 0
		for e in world:query(relationship):iter() do
			counter += 1
		end
		CHECK(counter == 1)
	end

	do CASE "query single component"
		do
			local world = jecs.world()
			local A = world:component()
			local B = world:component()

			local entities = {}
			for i = 1, N do
				local id = world:entity()

				world:set(id, A, true)
				if i > 5 then
					world:set(id, B, true)
				end
				entities[i] = id
			end

			for id in world:query(A) :: any do
				table.remove(entities, CHECK(table.find(entities, id)))
			end

			CHECK(#entities == 0)
		end

		do
			local world = jecs.world()
			local A = world:component()
			local B = world:component()
			local eA = world:entity()
			world:set(eA, A, true)
			local eB = world:entity()
			world:set(eB, B, true)
			local eAB = world:entity()
			world:set(eAB, A, true)
			world:set(eAB, B, true)

			-- Should drain the iterator
			local q = world:query(A)

			local i = 0
			local j = 0
			for _ in q :: any do
				i += 1
			end
			for _ in q :: any do
				j += 1
			end
			CHECK(i == 2)
			CHECK(j == 0)
		end
	end

	do CASE "query missing component"
		local world = jecs.world()
		local A = world:component()
		local B = world:component()
		local C = world:component()

		local e1 = world:entity()
		local e2 = world:entity()

		world:set(e1, A, "abc")
		world:set(e2, A, "def")
		world:set(e1, B, 123)
		world:set(e2, B, 457)

		local counter = 0
		for _ in world:query(B, C) :: any do
			counter += 1
		end
		CHECK(counter == 0)
	end

	do CASE "query more than 8 components"
		local world = jecs.world()
		local components = {}

		for i = 1, 9 do
			local id = world:component()
			components[i] = id
		end
		local e1 = world:entity()
		for i, id in components do
			world:set(e1, id, 13 ^ i)
		end

		for entity, a, b, c, d, e, f, g, h, i in world:query(unpack(components)) :: any do
			CHECK(a == 13 ^ 1)
			CHECK(b == 13 ^ 2)
			CHECK(c == 13 ^ 3)
			CHECK(d == 13 ^ 4)
			CHECK(e == 13 ^ 5)
			CHECK(f == 13 ^ 6)
			CHECK(g == 13 ^ 7)
			CHECK(h == 13 ^ 8)
			CHECK(i == 13 ^ 9)
		end
	end

	do CASE "should be able to get next results"
		local world = jecs.world()
		world:component()
		local A = world:component()
		local B = world:component()
		local eA = world:entity()
		world:set(eA, A, true)
		local eB = world:entity()
		world:set(eB, B, true)
		local eAB = world:entity()
		world:set(eAB, A, true)
		world:set(eAB, B, true)

		local it = world:query(A):iter()

		local e, data = it()
		while e do
			if e == eA then
				CHECK(data)
			elseif e == eAB then
				CHECK(data)
			else
				CHECK(false)
			end

			e, data = it()
		end
		CHECK(true)
	end

	do CASE "should query all matching entities when irrelevant component is removed"
		local world = jecs.world()
		local A = world:component()
		local B = world:component()

		local entities = {}
		for i = 1, N do
			local id = world:entity()

			-- specifically put them in disorder to track regression
			-- https://github.com/Ukendio/jecs/pull/15
			world:set(id, B, true)
			world:set(id, A, true)
			if i > 5 then
				world:remove(id, B)
			end
			entities[i] = id
		end

		local added = 0
		for id in world:query(A) :: any do
			added += 1
			table.remove(entities, CHECK(table.find(entities, id)))
		end

		CHECK(added == N)
	end

	do CASE "should query all entities without B"
		local world = jecs.world()
		local A = world:component()
		local B = world:component()

		local entities = {}
		for i = 1, N do
			local id = world:entity()

			world:set(id, A, true)
			if i < 5 then
				entities[i] = id
			else
				world:set(id, B, true)
			end
		end

		for id in world:query(A):without(B) :: any do
			table.remove(entities, CHECK(table.find(entities, id)))
		end

		CHECK(#entities == 0)
	end

	do CASE "should allow querying for relations"
		local world = jecs.world()
		local Eats = world:component()
		local Apples = world:component()
		local bob = world:entity()

		world:set(bob, pair(Eats, Apples), true)
		for e, bool in world:query(pair(Eats, Apples)) :: any do
			CHECK(e == bob)
			CHECK(bool)
		end
	end

	do CASE "should allow wildcards in queries"
		local world = jecs.world()
		local Eats = world:component()
		local Apples = world:entity()
		local bob = world:entity()

		world:set(bob, pair(Eats, Apples), "bob eats apples")

		local w = jecs.Wildcard
		for e, data in world:query(pair(Eats, w)) :: any do
			CHECK(e == bob)
			CHECK(data == "bob eats apples")
		end
		for e, data in world:query(pair(w, Apples)) :: any do
			CHECK(e == bob)
			CHECK(data == "bob eats apples")
		end
	end

	do CASE "should match against multiple pairs"
		local world = jecs.world()
		local Eats = world:component()
		local Apples = world:entity()
		local Oranges = world:entity()
		local bob = world:entity()
		local alice = world:entity()

		world:set(bob, pair(Eats, Apples), "bob eats apples")
		world:set(alice, pair(Eats, Oranges), "alice eats oranges")

		local w = jecs.Wildcard
		local count = 0
		for e, data in world:query(pair(Eats, w)) :: any do
			count += 1
			if e == bob then
				CHECK(data == "bob eats apples")
			else
				CHECK(data == "alice eats oranges")
			end
		end

		CHECK(count == 2)
		count = 0

		for e, data in world:query(pair(w, Apples)) :: any do
			count += 1
			CHECK(data == "bob eats apples")
		end
		CHECK(count == 1)
	end

	do CASE "should only relate alive entities"
		local world = jecs.world()
		local Eats = world:entity()
		local Apples = world:component()
		local Oranges = world:component()
		local bob = world:entity()
		local alice = world:entity()

		world:set(bob, Apples, "apples")
		world:set(bob, pair(Eats, Apples), "bob eats apples")
		world:set(alice, pair(Eats, Oranges), "alice eats oranges")

		world:delete(Apples)
		local Wildcard = jecs.Wildcard

		local count = 0
		for _, data in world:query(pair(Wildcard, Apples)) :: any do
			count += 1
		end

		world:delete(pair(Eats, Apples))

		CHECK(count == 0)
		CHECK(world:get(bob, pair(Eats, Apples)) == nil)

	end

	do
		CASE("should error when setting invalid pair")
		local world = jecs.world()
		local Eats = world:component()
		local Apples = world:component()
		local bob = world:entity()

		world:delete(Apples)
		CHECK_EXPECT_ERR(function()
			world:set(bob, pair(Eats, Apples), "bob eats apples")
		end)
	end

	do
		CASE("should find target for ChildOf")
		local world = jecs.world()
		local ChildOf = jecs.ChildOf

		local Name = world:component()

		local bob = world:entity()
		local alice = world:entity()
		local sara = world:entity()

		world:add(bob, pair(ChildOf, alice))
		world:set(bob, Name, "bob")
		world:add(sara, pair(ChildOf, alice))
		world:set(sara, Name, "sara")
		CHECK(world:parent(bob) == alice) -- O(1)

		local count = 0
		for _, name in world:query(Name, pair(ChildOf, alice)) :: any do
			count += 1
		end
		CHECK(count == 2)
	end

	do
		CASE("despawning while iterating")
		local world = jecs.world()
		local A = world:component()
		local B = world:component()

		local e1 = world:entity()
		local e2 = world:entity()
		world:add(e1, A)
		world:add(e2, A)
		world:add(e2, B)

		local count = 0
		for id in world:query(A) :: any do
			world:clear(id)
			count += 1
		end
		CHECK(count == 2)
	end

	do CASE "should not find any entities"
		local world = jecs.world()

		local Hello = world:component()
		local Bob = world:component()

		local helloBob = world:entity()
		world:add(helloBob, pair(Hello, Bob))
		world:add(helloBob, Bob)

		local withoutCount = 0
		for _ in world:query(pair(Hello, Bob)):without(Bob) :: any do
			withoutCount += 1
		end

		CHECK(withoutCount == 0)
	end

	do CASE "world:query():without()"
		-- REGRESSION TEST
		local world = jecs.world()
		local _1, _2, _3 = world:component(), world:component(), world:component()

		local counter = 0
		for e, a, b in world:query(_1, _2):without(_3) :: any do
			counter += 1
		end
		CHECK(counter == 0)
	end
end)

TEST("world:remove()", function()
	do
		CASE("should allow remove a component that doesn't exist on entity")
		local world = jecs.world()

		local Health = world:component()
		local Poison = world:component()

		local id = world:entity()
		do
			world:remove(id, Poison)
			CHECK(true) -- Didn't error
		end

		world:set(id, Health, 50)
		world:remove(id, Poison)

		CHECK(world:get(id, Poison) == nil)
		CHECK(world:get(id, Health) == 50)
	end
end)

TEST("world:set()", function()
	do CASE "archetype move"
		local world = jecs.world()

		local d = dwi(world)

		local _1 = world:component()
		local _2 = world:component()
		local e = world:entity()
		-- An entity starts without an archetype or row
		-- should therefore not need to copy over data
		CHECK(d.tbl(e) == nil)
		CHECK(d.row(e) == nil)

		local archetypes = #world.archetypes
		-- This should create a new archetype since it is the first
		-- entity to have moved there
		world:set(e, _1, 1)
		local oldRow = d.row(e)
		local oldArchetype = d.archetype(e)
		CHECK(#world.archetypes == archetypes + 1)
		CHECK(oldArchetype == "1")
		CHECK(d.tbl(e))
		CHECK(oldRow == 1)

		world:set(e, _2, 2)
		CHECK(d.archetype(e) == "1_2")
		-- Should have tuple of fields to the next archetype and set the component data
		CHECK(d.tuple(e, 1, 2))
		-- Should have moved the data from the old archetype
		CHECK(world.archetype_index[oldArchetype].columns[_1 :: any][oldRow] == nil)
	end

	do CASE "pairs"
		local world = jecs.world()

		local C1 = world:component()
		local C2 = world:component()
		local T1 = world:entity()
		local T2 = world:entity()

		local e = world:entity()

		world:set(e, pair(C1, C2), true)
		world:set(e, pair(C1, T1), true)
		world:set(e, pair(T1, C1), true)

		CHECK_EXPECT_ERR(function()
			world:set(e, pair(T1, T2), true :: any)
		end)

		CHECK(world:get(e, pair(C1, C2)))
		CHECK(world:get(e, pair(C1, T1)))
		CHECK(world:get(e, pair(T1, C1)))
		CHECK(not world:get(e, pair(T1, T2)))

		local e2 = world:entity()

		CHECK_EXPECT_ERR(function()
			world:set(e2, pair(jecs.ChildOf, e), true :: any)
		end)
		CHECK(not world:get(e2, pair(jecs.ChildOf, e)))
	end
end)

TEST("world:target", function()
	do CASE "nth index"
		local world = jecs.world()
		local A = world:component()
		world:set(A, jecs.Name, "A")
		local B = world:component()
		world:set(B, jecs.Name, "B")
		local C = world:component()
		world:set(C, jecs.Name, "C")
		local D = world:component()
		world:set(D, jecs.Name, "D")
		local E = world:component()
		world:set(E, jecs.Name, "E")
		local e = world:entity()

		world:add(e, pair(A, B))
		world:add(e, pair(A, C))
		world:add(e, pair(A, D))
		world:add(e, pair(A, E))
		world:add(e, pair(B, C))
		world:add(e, pair(B, D))
		world:add(e, pair(C, D))

		CHECK((pair(A, B) :: any) < (pair(A, C) :: any))
		CHECK((pair(A, C) :: any) < (pair(A, D) :: any))
		CHECK((pair(C, A) :: any) < (pair(C, D) :: any))

		CHECK(jecs.pair_first(world, pair(B, C)) == B)
		local r = (jecs.entity_index_try_get(world.entity_index :: any, e :: any) :: any) :: jecs.Record
		local archetype = r.archetype
		local function cdr(id)
			return assert(jecs.component_record(world, id))
		end
		local idr_b_c = cdr(pair(B, C))
		local idr_a_wc = cdr(pair(A, __))
		local idr_a_e = cdr(pair(A, E))

		CHECK(idr_a_wc.counts[archetype.id] == 4)
		CHECK(idr_b_c.records[archetype.id] > idr_a_e.records[archetype.id])
		CHECK(world:target(e, A, 0) == B)
		CHECK(world:target(e, A, 1) == C)
		CHECK(world:target(e, A, 2) == D)
		CHECK(world:target(e, A, 3) == E)
		CHECK(world:target(e, B, 0) == C)
		CHECK(world:target(e, B, 1) == D)
		CHECK(world:target(e, C, 0) == D)
		CHECK(world:target(e, C, 1) == nil)

		CHECK(cdr(pair(A, B)).records[archetype.id] == 1)
		CHECK(cdr(pair(A, C)).records[archetype.id] == 2)
		CHECK(cdr(pair(A, D)).records[archetype.id] == 3)
		CHECK(cdr(pair(A, E)).records[archetype.id] == 4)

		CHECK(world:target(e, C, 0) == D)
		CHECK(world:target(e, C, 1) == nil)
	end

	do CASE "infer index when unspecified"
		local world = jecs.world()
		local A = world:component()
		local B = world:component()
		local C = world:component()
		local D = world:component()
		local e = world:entity()

		world:add(e, pair(A, B))
		world:add(e, pair(A, C))
		world:add(e, pair(B, C))
		world:add(e, pair(B, D))
		world:add(e, pair(C, D))

		CHECK(world:target(e, A) == world:target(e, A, 0))
		CHECK(world:target(e, B) == world:target(e, B, 0))
		CHECK(world:target(e, C) == world:target(e, C, 0))
	end

	do CASE "loop until no target"
		local world = jecs.world()

		local ROOT = world:entity()
		local e1 = world:entity()
		local targets = {}

		for i = 1, 10 do
			local target = world:entity()
			targets[i] = target
			world:add(e1, pair(ROOT, target))
		end

		local i = 0
		local target = world:target(e1, ROOT, 0)
		while target do
			i += 1
			CHECK(targets[i] == target)
			target = world:target(e1, ROOT, i)
		end

		CHECK(i == 10)
	end
end)

TEST("#adding a recycled target", function()
    local world = jecs.world()
    local R = world:component()

    local e = world:entity()
    local T = world:entity()
    world:add(e, pair(R, T))
    world:delete(T)
    CHECK(not world:has(e, pair(R, T)))
    local T2 = world:entity()
    world:add(e, pair(R, T2))
    CHECK(world:target(e, R) ~= T)
    CHECK(world:target(e, R) ~= 0 :: any)

end)

TEST("#repro2", function()
	local world = jecs.world()
	local Lifetime = world:component() :: Id<number>
	local Particle = world:entity()
	local Beam = world:entity()

	local entity = world:entity()
	world:set(entity, pair(Lifetime, Particle), 1)
	world:set(entity, pair(Lifetime, Beam), 2)
	world:set(entity, pair(4 :: any, 5 :: any), 6) -- noise

	-- entity_visualizer.components(world, entity)

	for e in world:each(pair(Lifetime, __)) do
		local i = 0
		local nth = world:target(e, Lifetime, i)
		while nth do
			-- entity_visualizer.components(world, e)

			local data = world:get(e, pair(Lifetime, nth)) :: number
			data -= 1
		 	if data <= 0 then
                world:remove(e, pair(Lifetime, nth))
            else
                world:set(e, pair(Lifetime, nth), data)
            end
			i += 1
			nth = world:target(e, Lifetime, i)
		end
	end

	CHECK(not world:has(entity, pair(Lifetime, Particle)))
	CHECK(world:get(entity, pair(Lifetime, Beam)) == 1)
end)

TEST("another", function()
	local world = jecs.world()
	-- world = lifetime_tracker_add(world, {padding_enabled=false})
	local e1 = world:entity()
	local e2 = world:entity()
	local e3 = world:entity()
	world:delete(e2)
	local e2_e3 = pair(e2, e3)
	CHECK(jecs.pair_first(world, e2_e3) == 0 :: any)
	CHECK(jecs.pair_second(world, e2_e3) == e3)
	CHECK_EXPECT_ERR(function()
		world:add(e1, pair(e2, e3))
	end)
end)

TEST("#repro", function()
	local world = jecs.world()

	local function getTargets(relation)
		local tgts = {}
		local pairwildcard = pair(relation, jecs.Wildcard)
		local idr = assert(jecs.component_record(world, pairwildcard))
		local counts = idr.counts
		local records = idr.records
		for _, archetype in world:query(pairwildcard):archetypes() do
			local archetype_id = archetype.id
			local count = counts[archetype_id]
			local tr = records[archetype_id]
			local types = archetype.types
			for _, entity in archetype.entities do
			    for i = 0, count - 1 do
				    local tgt = jecs.pair_second(world, types[i + tr] :: any)
				    table.insert(tgts, tgt)
			    end
			end
		end
		return tgts
	end

	local Attacks = world:component()
	local Eats = world:component()

	local function setAttacksAndEats(entity1, entity2)
		world:add(entity1, pair(Attacks, entity2))
		world:add(entity1, pair(Eats, entity2))
	end

	local e1 = world:entity()
	local e2 = world:entity()
	local e3 = world:entity()
	setAttacksAndEats(e3, e1)
	setAttacksAndEats(e3, e2)
	setAttacksAndEats(e1, e2)
	local d = dwi(world)
	world:delete(e2)
	local types1 = { pair(Attacks, e1), pair(Eats, e1) }
	table.sort(types1)


	CHECK(d.tbl(e1).type == "")
	CHECK(d.tbl(e3).type == table.concat(types1, "_"))

	for _, entity in getTargets(Attacks) do
		CHECK(entity == e1)
	end
	for _, entity in getTargets(Eats) do
		CHECK(entity == e1)
	end
end)

TEST("Hooks", function()
	do CASE "OnAdd"
		local world = jecs.world()
		local Transform = world:component()
		local e1 = world:entity()
		world:set(Transform, jecs.OnAdd, function(entity)
			CHECK(e1 == entity)
		end)
		world:add(e1, Transform)
	end

	do CASE "OnSet"
		local world = jecs.world()
		local Number = world:component()
		local e1 = world:entity()

		local call = 0
		world:set(Number, jecs.OnChange, function(entity, data)
			CHECK(e1 == entity)
			if call == 1 then
				CHECK(false)
			elseif call == 2 then
				CHECK(world:get(entity, Number) == data)
			end
			CHECK(data == 1)
		end)

		call = 1
		world:set(e1, Number, 1)
		call = 2
		world:set(e1, Number, 1)
	end

	do CASE("OnRemove")
		do
			-- basic
			local world = jecs.world()
			local A = world:component() :: Id<boolean>
			local e1 = world:entity()
			world:set(A, jecs.OnRemove, function(entity)
				CHECK(e1 == entity)
				CHECK(world:has(e1, A))
			end)
			world:add(e1, A)

			world:remove(e1, A)
			CHECK(not world:has(e1, A))
		end
		do
			-- [BUG] https://github.com/Ukendio/jecs/issues/118
			local world = jecs.world()
			local A = world:component()
			local B = world:component()
			local e = world:entity()

			world:set(A, jecs.OnRemove, function(entity)
				world:set(entity, B, true)
				CHECK(world:get(entity, A))
				CHECK(world:get(entity, B))
			end)

			world:set(e, A, true)
			world:remove(e, A)
			CHECK(not world:get(e, A))
			CHECK(world:get(e, B))
		end
	end
end)

TEST("change tracking", function()
	do CASE "#1"
		local world = jecs.world()
		local Foo = world:component() :: Id<number>
		local Previous = jecs.Rest

		local q1 = world
			:query(Foo)
			:without(pair(Previous, Foo))
			:cached()

		local e1 = world:entity()
		world:set(e1, Foo, 1)
		local e2 = world:entity()
		world:set(e2, Foo, 2)

		local i = 0
		for e, new in q1 :: any do
			i += 1
			world:set(e, pair(Previous, Foo), new)
		end

		CHECK(i == 2)
		local j = 0
		for e, new in q1 :: any do
			j += 1
			world:set(e, pair(Previous, Foo), new)
		end

		CHECK(j == 0)
	end

	do CASE "#2"
		local world = jecs.world()
		local component = world:component() :: Id<number>
		local tag = world:entity()
		local previous = jecs.Rest

		local q1 = world:query(component):without(pair(previous, component), tag):cached()

		local testEntity = world:entity()

		world:set(testEntity, component, 10)

		local i = 0
		for entity, number in q1 :: any do
			i += 1
			world:add(testEntity, tag)
		end

		CHECK(i == 1)

		for e, n in q1 :: any do
			world:set(e, pair(previous, component), n)
		end
	end

end)

TEST("repro", function()
	do CASE "#1"
		local world = jecs.world()
		local reproEntity = world:component()
		local components = { Cooldown = world:component() :: Id<number> }
		world:set(reproEntity, components.Cooldown, 2)

		local function updateCooldowns(dt: number)
			local toRemove = {}

			local it = world:query(components.Cooldown):iter()
			for id, cooldown in it do
				cooldown -= dt

				if cooldown <= 0 then
					table.insert(toRemove, id)
					-- world:remove(id, components.Cooldown)
				else
					world:set(id, components.Cooldown, cooldown)
				end
			end

			for _, id in toRemove do
				world:remove(id, components.Cooldown)
				CHECK(not world:get(id, components.Cooldown))
			end
		end

		updateCooldowns(1.5)
		updateCooldowns(1.5)
	end

	do CASE "#2" -- ISSUE #171
		local world = jecs.world()
		local component1 = world:component()
		local tag1 = world:entity()

		local query = world:query(component1):with(tag1):cached()

		local entity = world:entity()
		world:set(entity, component1, "some data")

		local counter = 0
		for x in query:iter() do
			counter += 1
		end
		CHECK(counter == 0)
	end
end)

TEST("wildcard query", function()
	do CASE "#1"
		local world = jecs.world()
		local pair = jecs.pair

		local Relation = world:entity()
		local Wildcard = jecs.Wildcard
		local A = world:entity()

		local relationship = pair(Relation, Wildcard)
		local query = world:query(relationship):cached()

		local entity = world:entity()

		local p = pair(Relation, A)
		CHECK(jecs.pair_first(world, p) == Relation)
		CHECK(jecs.pair_second(world, p) == A)
		world:add(entity, pair(Relation, A))

		local counter = 0
		for e in query:iter() do
			counter += 1
		end
		CHECK(counter == 1)
	end
	do CASE "#2"
		local world = jecs.world()
		local pair = jecs.pair

		local Relation = world:entity()
		local Wildcard = jecs.Wildcard
		local A = world:entity()

		local relationship = pair(Relation, Wildcard)

		local entity = world:entity()

		world:add(entity, pair(Relation, A))

		local counter = 0
		for e in world:query(relationship):iter() do
			counter += 1
		end
		CHECK(counter == 1)
	end
	do CASE "#3"
		local world = jecs.world()
		local pair = jecs.pair

		local Relation = world:entity()
		local Wildcard = jecs.Wildcard
		local A = world:entity()

		local entity = world:entity()

		world:add(entity, pair(Relation, A))

		local relationship = pair(Relation, Wildcard)
		local query = world:query(relationship):cached()

		local counter = 0
		for e in query:iter() do
			counter += 1
		end
		CHECK(counter == 1)
	end
end)

return FINISH()
