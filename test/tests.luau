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
local entity_index_try_get_any = jecs.entity_index_try_get_any
local entity_index_get_alive = jecs.entity_index_get_alive
local entity_index_is_alive = jecs.entity_index_is_alive
local ChildOf = jecs.ChildOf
local world_new = jecs.World.new

local TEST, CASE, CHECK, FINISH, SKIP, FOCUS = testkit.test()

local N = 2 ^ 8

type World = jecs.World
type Entity<T=nil> = jecs.Entity<T>

local function debug_world_inspect(world: World)
	local function record(e): jecs.Record
		return entity_index_try_get_any(world.entity_index, e) :: any
	end
	local function tbl(e)
		return record(e).archetype
	end
	local function archetype(e)
		return tbl(e).type
	end
	local function records(e)
		return tbl(e).records
	end
	local function columns(e)
		return tbl(e).columns
	end
	local function row(e)
		return record(e).row
	end

	-- Important to order them in the order of their columns
	local function tuple(e, ...)
		for i, column in columns(e) do
			if select(i, ...) ~= column[row(e)] then
				return false
			end
		end
		return true
	end

	return {
		record = record,
		tbl = tbl,
		archetype = archetype,
		records = records,
		row = row,
		tuple = tuple,
		columns = columns
	}
end

local function name(world, e)
	return world:get(e, jecs.Name)
end

TEST("archetype", function()
	local archetype_append_to_records = jecs.archetype_append_to_records
	local id_record_ensure = jecs.id_record_ensure
	local archetype_create = jecs.archetype_create
	local archetype_ensure = jecs.archetype_ensure
	local find_insert = jecs.find_insert
	local find_archetype_with = jecs.find_archetype_with
	local find_archetype_without = jecs.find_archetype_without
	local archetype_init_edge = jecs.archetype_init_edge
	local archetype_ensure_edge = jecs.archetype_ensure_edge
	local init_edge_for_add = jecs.init_edge_for_add
	local init_edge_for_remove = jecs.init_edge_for_remove
	local create_edge_for_add = jecs.create_edge_for_add
	local create_edge_for_remove = jecs.create_edge_for_remove
	local archetype_traverse_add = jecs.archetype_traverse_add
	local archetype_traverse_remove = jecs.archetype_traverse_remove

	local world = world_new()
	local root = world.ROOT_ARCHETYPE
	local c1 = world:component()
	local c2 = world:component()
	local c3 = world:component()

	local a1 = archetype_traverse_add(world, c1, nil)
	local a2 = archetype_traverse_remove(world, c1, a1)
	CHECK(root.add[c1].to == a1)
	CHECK(root == a2)
end)

TEST("world:cleanup()", function()
	local world = world_new()
	local A = world:component()
	local B = world:component()
	local C = world:component()

	local e1 = world:entity()
	local e2 = world:entity()
	local e3 = world:entity()

	world:set(e1, A, true)

	world:set(e2, A, true)
	world:set(e2, B, true)


	world:set(e3, A, true)
	world:set(e3, B, true)
	world:set(e3, C, true)

	local archetypeIndex = world.archetypeIndex

	CHECK(#archetypeIndex["1"].entities == 1)
	CHECK(#archetypeIndex["1_2"].entities == 1)
	CHECK(#archetypeIndex["1_2_3"].entities == 1)

	world:delete(e1)
	world:delete(e2)
	world:delete(e3)

	world:cleanup()

	archetypeIndex = world.archetypeIndex

	CHECK((archetypeIndex["1"] :: jecs.Archetype?) == nil)
	CHECK((archetypeIndex["1_2"] :: jecs.Archetype?) == nil)
	CHECK((archetypeIndex["1_2_3"] :: jecs.Archetype?) == nil)

	local e4 = world:entity()
	world:set(e4, A, true)
	CHECK(#archetypeIndex["1"].entities == 1)
	CHECK((archetypeIndex["1_2"] :: jecs.Archetype?) == nil)
	CHECK((archetypeIndex["1_2_3"] :: jecs.Archetype?) == nil)
	world:set(e4, B, true)
	CHECK(#archetypeIndex["1"].entities == 0)
	CHECK(#archetypeIndex["1_2"].entities == 1)
	CHECK((archetypeIndex["1_2_3"] :: jecs.Archetype?) == nil)
	world:set(e4, C, true)
	CHECK(#archetypeIndex["1"].entities == 0)
	CHECK(#archetypeIndex["1_2"].entities == 0)
	CHECK(#archetypeIndex["1_2_3"].entities == 1)
end)

TEST("world:entity()", function()
	do
		CASE("unique IDs")
		local world = jecs.World.new()
		local set = {}
		for i = 1, N do
			local e = world:entity()
			CHECK(not set[e])
			set[e] = true
		end
	end
	do
		CASE("generations")
		local world = jecs.World.new()
		local e = world:entity()
		CHECK(ECS_ID(e) == 1 + jecs.Rest :: number)
		CHECK(ECS_GENERATION(e) == 0) -- 0
		e = ECS_GENERATION_INC(e)
		CHECK(ECS_GENERATION(e) == 1) -- 1
	end

	do CASE("pairs")
		local world = jecs.World.new()
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
		local e2v2 = world:entity()
		CHECK(IS_PAIR(e2v2) == false)

		CHECK(IS_PAIR(pair(e2v2, e3)) == true)
	end

	do CASE "Recycling"
		local world = world_new()
		local e = world:entity()
		world:delete(e)
		local e1 = world:entity()
		world:delete(e1)
		local e2 = world:entity()
		CHECK(ECS_ID(e2) == e)
		CHECK(ECS_GENERATION(e2) == 2)
		CHECK(world:contains(e2))
		CHECK(not world:contains(e1))
		CHECK(not world:contains(e))
	end

	do CASE "Recycling max generation"
		local world = world_new()
		local pin = jecs.Rest::number + 1
		for i = 1, 2^16-1 do
			local e = world:entity()
			world:delete(e)
		end
		local e = world:entity()
		CHECK(ECS_ID(e) == pin)
		CHECK(ECS_GENERATION(e) == 2^16-1)
		world:delete(e)
		e = world:entity()
		CHECK(ECS_ID(e) == pin)
		CHECK(ECS_GENERATION(e) == 0)
	end
end)

TEST("world:set()", function()
	do
		CASE("archetype move")
		do
			local world = jecs.World.new()

			local d = debug_world_inspect(world)

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
			CHECK(world.archetypeIndex[oldArchetype].columns[_1][oldRow] == nil)
		end
	end

	do
		CASE("arbitrary order")
		local world = jecs.World.new()

		local Health = world:entity()
		local Poison = world:component()

		local id = world:entity()
		world:set(id, Poison, 5)
		world:set(id, Health, 50)

		CHECK(world:get(id, Poison) == 5)
	end

	do
		CASE("pairs")
		local world = jecs.World.new()

		local C1 = world:component()
		local C2 = world:component()
		local T1 = world:entity()
		local T2 = world:entity()

		local e = world:entity()

		world:set(e, pair(C1, C2), true)
		world:set(e, pair(C1, T1), true)
		world:set(e, pair(T1, C1), true)
		world:set(e, pair(T1, T2), true)

		CHECK(world:get(e, pair(C1, C2)))
		CHECK(world:get(e, pair(C1, T1)))
		CHECK(world:get(e, pair(T1, C1)))
		CHECK(not world:get(e, pair(T1, T2)))

		local e2 = world:entity()

		world:set(e2, pair(jecs.ChildOf, e), true)
		CHECK(not world:get(e2, pair(jecs.ChildOf, e)))
	end
end)

TEST("world:remove()", function()
	do
		CASE("should allow remove a component that doesn't exist on entity")
		local world = jecs.World.new()

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

TEST("world:add()", function()
	do
		CASE("idempotent")
		local world = jecs.World.new()
		local d = debug_world_inspect(world)
		local _1, _2 = world:component(), world:component()

		local e = world:entity()
		world:add(e, _1)
		world:add(e, _2)
		world:add(e, _2) -- should have 0 effects
		CHECK(d.archetype(e) == "1_2")
	end

	do
		CASE("archetype move")
		do
			local world = jecs.World.new()

			local d = debug_world_inspect(world)

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
	end
end)

TEST("world:query()", function()
	do CASE "cached"
		local world = world_new()
		local Foo = world:component()
		local Bar = world:component()
		local Baz = world:component()
		local e = world:entity()
		local q = world:query(Foo, Bar):without(Baz):cached()
		world:set(e, Foo, true)
		world:set(e, Bar, false)
		local i = 0

		local iter = 0
		for _, e in q:iter() do
			iter += 1
			i=1
		end
		CHECK (iter == 1)
		CHECK(i == 1)
		for _, e in q:iter() do
			i=2
		end
		CHECK(i == 2)
		for _, e in q do
			i=3
		end
		CHECK(i == 3)
		for _, e in q do
			i=4
		end
		CHECK(i == 4)

		CHECK(#q:archetypes() == 1)
		CHECK(not table.find(q:archetypes(), world.archetypes[table.concat({Foo, Bar, Baz}, "_")]))
		world:delete(Foo)
		CHECK(#q:archetypes() == 0)
	end
	do CASE("multiple iter")
		local world = jecs.World.new()
		local A = world:component()
		local B = world:component()
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
	do
		CASE("tag")
		local world = jecs.World.new()
		local A = world:entity()
		local e = world:entity()
		world:set(e, A, "test")
		for id, a in world:query(A) do
			CHECK(a == nil)
		end
	end
	do
		CASE("pairs")
		local world = jecs.World.new()

		local C1 = world:component()
		local C2 = world:component()
		local T1 = world:entity()
		local T2 = world:entity()

		local e = world:entity()

		world:set(e, pair(C1, C2), true)
		world:set(e, pair(C1, T1), true)
		world:set(e, pair(T1, C1), true)
		world:set(e, pair(T1, T2), true)

		for id, a, b, c, d in world:query(pair(C1, C2), pair(C1, T1), pair(T1, C1), pair(T1, T2)) do
			CHECK(a == true)
			CHECK(b == true)
			CHECK(c == true)
			CHECK(d == nil)
		end
	end
	do
		CASE("query single component")
		do
			local world = jecs.World.new()
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

			for id in world:query(A) do
				table.remove(entities, CHECK(table.find(entities, id)))
			end

			CHECK(#entities == 0)
		end

		do
			local world = jecs.World.new() :: World
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
			for _ in q do
				i += 1
			end
			for _ in q do
				j += 1
			end
			CHECK(i == 2)
			CHECK(j == 0)
		end
	end

	do
		CASE("query missing component")
		local world = jecs.World.new()
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
		for _ in world:query(B, C) do
			counter += 1
		end
		CHECK(counter == 0)
	end

	do
		CASE("query more than 8 components")
		local world = jecs.World.new()
		local components = {}

		for i = 1, 9 do
			local id = world:component()
			components[i] = id
		end
		local e = world:entity()
		for i, id in components do
			world:set(e, id, 13 ^ i)
		end

		for entity, a, b, c, d, e, f, g, h, i in world:query(unpack(components)) do
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

	do
		CASE("should be able to get next results")
		local world = jecs.World.new() :: World
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

	do
		CASE("should query all matching entities when irrelevant component is removed")
		local world = jecs.World.new()
		local A = world:component()
		local B = world:component()
		local C = world:component()

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
		for id in world:query(A) do
			added += 1
			table.remove(entities, CHECK(table.find(entities, id)))
		end

		CHECK(added == N)
	end

	do
		CASE("should query all entities without B")
		local world = jecs.World.new()
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

		for id in world:query(A):without(B) do
			table.remove(entities, CHECK(table.find(entities, id)))
		end

		CHECK(#entities == 0)
	end

	do
		CASE("should allow querying for relations")
		local world = jecs.World.new()
		local Eats = world:component()
		local Apples = world:component()
		local bob = world:entity()

		world:set(bob, pair(Eats, Apples), true)
		for e, bool in world:query(pair(Eats, Apples)) do
			CHECK(e == bob)
			CHECK(bool)
		end
	end

	do
		CASE("should allow wildcards in queries")
		local world = jecs.World.new()
		local Eats = world:component()
		local Apples = world:entity()
		local bob = world:entity()

		world:set(bob, pair(Eats, Apples), "bob eats apples")

		local w = jecs.Wildcard
		for e, data in world:query(pair(Eats, w)) do
			CHECK(e == bob)
			CHECK(data == "bob eats apples")
		end
		for e, data in world:query(pair(w, Apples)) do
			CHECK(e == bob)
			CHECK(data == "bob eats apples")
		end
	end

	do
		CASE("should match against multiple pairs")
		local world = jecs.World.new()
		local Eats = world:component()
		local Apples = world:entity()
		local Oranges = world:entity()
		local bob = world:entity()
		local alice = world:entity()

		world:set(bob, pair(Eats, Apples), "bob eats apples")
		world:set(alice, pair(Eats, Oranges), "alice eats oranges")

		local w = jecs.Wildcard
		local count = 0
		for e, data in world:query(pair(Eats, w)) do
			count += 1
			if e == bob then
				CHECK(data == "bob eats apples")
			else
				CHECK(data == "alice eats oranges")
			end
		end

		CHECK(count == 2)
		count = 0

		for e, data in world:query(pair(w, Apples)) do
			count += 1
			CHECK(data == "bob eats apples")
		end
		CHECK(count == 1)
	end

	do
		CASE("should only relate alive entities")
		SKIP()
		local world = jecs.World.new()
		local Eats = world:entity()
		local Apples = world:entity()
		local Oranges = world:entity()
		local bob = world:entity()
		local alice = world:entity()

		world:set(bob, Apples, "apples")
		world:set(bob, pair(Eats, Apples), "bob eats apples")
		world:set(alice, pair(Eats, Oranges), "alice eats oranges")

		world:delete(Apples)
		local Wildcard = jecs.Wildcard

		local count = 0
		for _, data in world:query(pair(Wildcard, Apples)) do
			count += 1
		end

		world:delete(pair(Eats, Apples))

		CHECK(count == 0)
		CHECK(world:get(bob, pair(Eats, Apples)) == nil)
	end

	do
		CASE("should error when setting invalid pair")
		local world = jecs.World.new()
		local Eats = world:component()
		local Apples = world:component()
		local bob = world:entity()

		world:delete(Apples)

		world:set(bob, pair(Eats, Apples), "bob eats apples")
	end

	do
		CASE("should find target for ChildOf")
		local world = jecs.World.new()
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
		for _, name in world:query(Name, pair(ChildOf, alice)) do
			count += 1
		end
		CHECK(count == 2)
	end

	do
		CASE("despawning while iterating")
		local world = jecs.World.new()
		local A = world:component()
		local B = world:component()

		local e1 = world:entity()
		local e2 = world:entity()
		world:add(e1, A)
		world:add(e2, A)
		world:add(e2, B)

		local count = 0
		for id in world:query(A) do
			world:clear(id)
			count += 1
		end
		CHECK(count == 2)
	end

	do
		CASE("iterator invalidation")
		do
			CASE("adding")
			SKIP()
			local world = jecs.World.new()
			local A = world:component()
			local B = world:component()

			local e1 = world:entity()
			local e2 = world:entity()
			world:add(e1, A)
			world:add(e2, A)
			world:add(e2, B)

			local count = 0
			for id in world:query(A) do
				world:add(id, B)

				count += 1
			end

			CHECK(count == 2)
		end

		do
			CASE("spawning")
			local world = jecs.World.new()
			local A = world:component()
			local B = world:component()

			local e1 = world:entity()
			local e2 = world:entity()
			world:add(e1, A)
			world:add(e2, A)
			world:add(e2, B)

			for id in world:query(A) do
				local e = world:entity()
				world:add(e, A)
				world:add(e, B)
			end

			CHECK(true)
		end
	end

	do
		CASE("should not find any entities")
		local world = jecs.World.new()

		local Hello = world:component()
		local Bob = world:component()

		local helloBob = world:entity()
		world:add(helloBob, pair(Hello, Bob))
		world:add(helloBob, Bob)

		local withoutCount = 0
		for _ in world:query(pair(Hello, Bob)):without(Bob) do
			withoutCount += 1
		end

		CHECK(withoutCount == 0)
	end

	do
		CASE("without")
		do
			-- REGRESSION TEST
			local world = jecs.World.new()
			local _1, _2, _3 = world:component(), world:component(), world:component()

			local counter = 0
			for e, a, b in world:query(_1, _2):without(_3) do
				counter += 1
			end
			CHECK(counter == 0)
		end
	end
end)

TEST("world:each", function()
	local world = world_new()
	local A = world:component()
	local B = world:component()
	local C = world:component()

	local e1 = world:entity()
	local e2 = world:entity()
	local e3 = world:entity()

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

TEST("world:children", function()
	local world = world_new()
	local C = world:component()
	local T = world:entity()

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
end)

TEST("world:clear()", function()
	do
		CASE("should remove its components")
		local world = jecs.World.new() :: World
		local A = world:component()
		local B = world:component()

		local e = world:entity()

		world:set(e, A, true)
		world:set(e, B, true)

		CHECK(world:get(e, A))
		CHECK(world:get(e, B))

		world:clear(e)
		CHECK(world:get(e, A) == nil)
		CHECK(world:get(e, B) == nil)
	end

	do
		CASE("should move last record")
		local world = world_new()
		local A = world:component()

		local e = world:entity()
		local e1 = world:entity()

		world:add(e, A)
		world:add(e1, A)

		local archetype = world.archetypeIndex["1"]
		local archetype_entities = archetype.entities

		local _e = e :: number
		local _e1 = e1 :: number

		CHECK(archetype_entities[1] == _e)
		CHECK(archetype_entities[2] == _e1)

		local e_record: jecs.Record = entity_index_try_get_any(
			world.entity_index, e) :: any
		local e1_record: jecs.Record = entity_index_try_get_any(
			world.entity_index, e1) :: any
		CHECK(e_record.archetype == archetype)
		CHECK(e1_record.archetype == archetype)
		CHECK(e1_record.row == 2)

		world:clear(e)

		CHECK((e_record.archetype :: jecs.Archetype?) == nil)
		CHECK((e_record.row :: number?) == nil)
		CHECK(e1_record.archetype == archetype)
		CHECK(e1_record.row == 1)

		CHECK(archetype_entities[1] == _e1)
		CHECK(archetype_entities[2] == nil)

		CHECK(world:contains(e) == true)
		CHECK(world:has(e, A) == false)
		CHECK(world:contains(e1) == true)
		CHECK(world:has(e1, A) == true)
	end
end)

TEST("world:has()", function()
	do
		CASE("should find Tag on entity")
		local world = jecs.World.new()

		local Tag = world:entity()

		local e = world:entity()
		world:add(e, Tag)

		CHECK(world:has(e, Tag))
	end

	do
		CASE("should return false when missing one tag")
		local world = jecs.World.new()

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

TEST("world:component()", function()
	do
		CASE("only components should have EcsComponent trait")
		local world = jecs.World.new() :: World
		local A = world:component()
		local e = world:entity()

		CHECK(world:has(A, jecs.Component))
		CHECK(not world:has(e, jecs.Component))
	end

	do CASE("tag")
		local world = jecs.World.new() :: World
		local A = world:component()
		local B = world:entity()
		local C = world:entity()
		local e = world:entity()
		world:set(e, A, "test")
		world:add(e, B)
		world:set(e, C, 11)

		CHECK(world:has(e, A))
		CHECK(world:get(e, A) == "test")
		CHECK(world:get(e, B) == nil)
		CHECK(world:get(e, C) == nil)
	end
end)

TEST("world:delete", function()
	do
		CASE("bug: Empty entity does not respect cleanup policy")
		local world = world_new()
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
	do
		CASE("should allow deleting components")
		local world = jecs.World.new()

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

	do
		CASE("delete entities using another Entity as component with Delete cleanup action")
		local world = jecs.World.new()

		local Health = world:entity()
		world:add(Health, pair(jecs.OnDelete, jecs.Delete))
		local Poison = world:component()

		local id = world:entity()
		world:set(id, Poison, 5)
		world:set(id, Health, 50)
		local id1 = world:entity()
		world:set(id1, Poison, 500)
		world:set(id1, Health, 50)

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

	do
		CASE("delete children")
		local world = jecs.World.new()

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

	do
		CASE("fast delete")
		local world = jecs.World.new()

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

	do
		CASE("cycle")
		local world = jecs.World.new()
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

TEST("world:target", function()
	do CASE("nth index")
		local world = world_new()
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

		CHECK(pair(A, B) < pair(A, C))
		CHECK(pair(A, E) < pair(B, C))

		local records = debug_world_inspect(world).records(e)
		CHECK(jecs.pair_first(world, pair(B, C)) == B)
		CHECK(records[pair(B, C)].column > records[pair(A, E)].column)
		CHECK(world:target(e, A, 0) == B)
		CHECK(world:target(e, A, 1) == C)
		CHECK(world:target(e, A, 2) == D)
		CHECK(world:target(e, A, 3) == E)
		CHECK(world:target(e, B, 0) == C)
		CHECK(world:target(e, B, 1) == D)
		CHECK(world:target(e, C, 0) == D)
		CHECK(world:target(e, C, 1) == nil)
	end

	do
		CASE("infer index when unspecified")
		local world = world_new()
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

	do
		CASE("loop until no target")
		local world = world_new()

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

TEST("world:contains", function()
	local world = jecs.World.new()
	local id = world:entity()
	CHECK(world:contains(id))

	do
		CASE("should not exist after delete")
		world:delete(id)
		CHECK(not world:contains(id))
	end
end)

TEST("Hooks", function()
	do CASE "OnAdd"
		local world = jecs.World.new()
		local Transform = world:component()
		local e1 = world:entity()
		world:set(Transform, jecs.OnAdd, function(entity)
			CHECK(e1 == entity)
		end)
		world:add(e1, Transform)
	end

	do CASE "OnSet"
		local world = jecs.World.new()
		local Number = world:component()
		local e1 = world:entity()

		world:set(Number, jecs.OnSet, function(entity, data)
			CHECK(e1 == entity)
			CHECK(data == world:get(entity, Number))
			CHECK(data == 1)
		end)
		world:set(e1, Number, 1)
	end

	do CASE("OnRemove")
		do
			-- basic
			local world = jecs.World.new()
			local A = world:component()
			local e1 = world:entity()
			world:add(e1, A)
			world:set(A, jecs.OnRemove, function(entity)
				CHECK(e1 == entity)
				CHECK(not world:has(e1, A))
			end)
			world:remove(e1, A)
			CHECK(not world:has(e1, A))
		end
		do
			-- [BUG] https://github.com/Ukendio/jecs/issues/118
			local world = world_new()
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
			CHECK(not world:get(e, B))
		end
	end
end)

TEST("change tracking", function()
	CASE "#1" do
		local world = world_new()
		local Foo = world:component()
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
		for e, new in q1 do
			i += 1
			world:set(e, pair(Previous, Foo), new)
		end

		CHECK(i == 2)
		local j = 0
		for e, new in q1 do
			j += 1
			world:set(e, pair(Previous, Foo), new)
		end

		CHECK(j == 0)
	end

	CASE "#2" do
		local world = world_new()
		local component = world:component()
		local tag = world:entity()
		local previous = jecs.Rest

		local q1 = world:query(component):without(pair(previous, component), tag):cached()

		local testEntity = world:entity()

		world:set(testEntity, component, 10)

		local i = 0
		for entity, number in q1 do
			i += 1
			world:add(testEntity, tag)
		end

		CHECK(i == 1)

		for e, n in q1 do
			world:set(e, pair(previous, component), n)
		end
	end

end)

TEST("repro", function()
	do CASE "#1"
		local world = world_new()
		local reproEntity = world:component()
		local components = { Cooldown = world:component() :: jecs.Id<number> }
		world:set(reproEntity, components.Cooldown, 2)

		local function updateCooldowns(dt: number)
			local toRemove = {}

			for id, cooldown in world:query(components.Cooldown):iter() do
				cooldown -= dt

				if cooldown <= 0 then
					table.insert(toRemove, id)
					print("removing")
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

	do CASE "#2"
		local world = jecs.World.new()

		export type Iterator<T> = () -> (Entity, T?, T?)
		export type Destructor = () -> ()

		-- Helpers

		type ValuesMap<T> = { [Entity]: T? }
		type ChangeSet = { [Entity]: true? }
		type ChangeSets = { [ChangeSet]: true? }
		type ChangeSetsCache = {
			Added: ChangeSets,
			Changed: ChangeSets,
			Removed: ChangeSets,
		}

		local cachedChangeSets = {}
		local function getChangeSets(component): ChangeSetsCache
			if cachedChangeSets[component] == nil then
				local changeSetsAdded: ChangeSets = {}
				local changeSetsChanged: ChangeSets = {}
				local changeSetsRemoved: ChangeSets = {}
				world:set(component, jecs.OnAdd, function(id)
					for set in changeSetsAdded do
						set[id] = true
					end
				end)
				world:set(component, jecs.OnSet, function(id)
					for set in changeSetsChanged do
						set[id] = true
					end
				end)
				world:set(component, jecs.OnRemove, function(id)
					for set in changeSetsRemoved do
						set[id] = true
					end
				end)
				cachedChangeSets[component] = {
					Added = changeSetsAdded,
					Changed = changeSetsChanged,
					Removed = changeSetsRemoved,
				}
			end
			return cachedChangeSets[component]
		end

		local function ChangeTracker<T>(component: jecs.Id): (Iterator<T>, Destructor)
			local values: ValuesMap<T> = {}
			local changeSet: ChangeSet = {}

			for id in world:query(component) do
				changeSet[id] = true
			end

			local changeSets = getChangeSets(component)
			changeSets.Added[changeSet] = true
			changeSets.Changed[changeSet] = true
			changeSets.Removed[changeSet] = true

			local id: jecs.Id? = nil
			local iter: Iterator<T> = function()
				id = next(changeSet)
				if id then
					changeSet[id] = nil
					local old: T? = values[id]
					local new: T? = world:get(id, component)
					if old ~= nil and new == nil then
						-- Old value but no new value = removed
						values[id] = nil
					else
						-- Old+new value or just new value = new becomes old
						values[id] = new
					end
					return id, old, new
				end
				return nil :: any, nil, nil
			end

			local destroy: Destructor = function()
				changeSets.Added[changeSet] = nil
				changeSets.Changed[changeSet] = nil
				changeSets.Removed[changeSet] = nil
			end

			return iter, destroy
		end

		local Transform = world:component()
		local iter, destroy = ChangeTracker(Transform)

		local e1 = world:entity()
		world:set(e1, Transform, { 1, 1 })
		local counter = 0
		for _ in iter do
			counter += 1
		end
		CHECK(counter == 1)
	end

	do CASE "#3" -- ISSUE #171
		local world = world_new()
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
		local world = world_new()
		local pair = jecs.pair

		local Relation = world:entity()
		local Wildcard = jecs.Wildcard
		local A = world:entity()

		local relationship = pair(Relation, Wildcard)
		local query = world:query(relationship):cached()

		local entity = world:entity()

		world:add(entity, pair(Relation, A))

		local counter = 0
		for e in query:iter() do
			counter += 1
		end
		CHECK(counter == 1)
	end
	do CASE "#2"
		local world = world_new()
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
		local world = world_new()
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

TEST("world:delete() invokes OnRemove hook", function()
	do CASE "#1"
		local world = world_new()
		
		local A = world:entity()
		local entity = world:entity()

		local called = false
		world:set(A, jecs.OnRemove, function(e)
			called = true
		end)

		world:add(entity, A)
		world:delete(entity)

		CHECK(called)
	end
	do CASE "#2"
		local world = world_new()
		local pair = jecs.pair

		local Relation = world:entity()
		local A = world:entity()
		local B = world:entity()

		world:add(Relation, pair(jecs.OnDelete, jecs.Delete))

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
	do CASE "#3"
		local world = world_new()
		local pair = jecs.pair

		local viewingContainer = world:entity()
		local character = world:entity()
		local container = world:entity()

		local called = false
		world:set(viewingContainer, jecs.OnRemove, function(e)
			called = true
		end)

		world:add(character, pair(viewingContainer, container))

		world:delete(container)

		CHECK(called)
	end
end)
FINISH()
