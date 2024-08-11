local jecs = require("@jecs")
local testkit = require("@testkit")
local __ = jecs.Wildcard
local ECS_ID, ECS_GENERATION = jecs.ECS_ID, jecs.ECS_GENERATION
local ECS_GENERATION_INC = jecs.ECS_GENERATION_INC
local IS_PAIR = jecs.IS_PAIR
local pair = jecs.pair
local getAlive = jecs.entity_index_get_alive
local ecs_pair_first = jecs.pair_first
local ecs_pair_second = jecs.pair_second

local TEST, CASE, CHECK, FINISH, SKIP = testkit.test()
local function CHECK_NO_ERR<T...>(s: string, fn: (T...) -> (), ...: T...)
	local ok, err: string? = pcall(fn, ...)

	if not CHECK(not ok, 2) then
		local i = string.find(err :: string, " ")
		assert(i)
		local msg = string.sub(err :: string, i + 1)
		CHECK(msg == s, 2)
	end
end
local N = 2^8

type World = jecs.WorldShim

local function debug_world_inspect(world)
    local function record(e)
        return world.entityIndex.sparse[e]
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
    }
end

TEST("world:entity()", function()
    do CASE "unique IDs"
        local world = jecs.World.new()
        local set = {}
        for i = 1, N do
            local e = world:entity()
            CHECK(not set[e])
            set[e] = true
        end
    end
    do CASE "generations"
		local world = jecs.World.new()
		local e = world:entity()
		CHECK(ECS_ID(e) == 1 + jecs.Rest)
		CHECK(getAlive(world.entityIndex, ECS_ID(e)) == e)
		CHECK(ECS_GENERATION(e) == 0) -- 0
		e = ECS_GENERATION_INC(e)
		CHECK(ECS_GENERATION(e) == 1) -- 1
	end

	do CASE "pairs"
		local world = jecs.World.new()
		local _e = world:entity()
		local e2 = world:entity()
		local e3 = world:entity()

		-- Incomplete pair, must have a bit flag that notes it is a pair
		CHECK(IS_PAIR(world:entity()) == false)

		local pair = pair(e2, e3)
		CHECK(IS_PAIR(pair) == true)

		CHECK(ecs_pair_first(world, pair) == e2)
		CHECK(ecs_pair_second(world, pair) == e3)
	end
end)

TEST("world:set()", function()
    do CASE "archetype move"
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

    do CASE "arbitrary order"
		local world = jecs.World.new()

		local Health = world:entity()
		local Poison = world:component()

		local id = world:entity()
		world:set(id, Poison, 5)
		world:set(id, Health, 50)

		CHECK(world:get(id, Poison) == 5)
	end
end)

TEST("world:remove()", function()
    do CASE "should allow remove a component that doesn't exist on entity"
		local world = jecs.World.new()

		local Health = world:entity()
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

    do CASE "idempotent"
        local world = jecs.World.new()
        local d = debug_world_inspect(world)
        local _1, _2 = world:component(), world:component()

        local e = world:entity()
        world:add(e, _1)
        world:add(e, _2)
        world:add(e, _2) -- should have 0 effects
        CHECK(d.archetype(e) == "1_2")
    end

    do CASE "archetype move"
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
    do CASE "query single component"
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
      		local q = world:query(A):drain()

      		local i = 0
      		local j = 0
      		for _ in q do
     			i+=1
      		end
      		for _ in q do
     			j+=1
      		end
      		CHECK(i == 2)
      		CHECK(j == 0)
       	end
    end

    do CASE "query missing component"
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

    do CASE "query more than 8 components"
        local world = jecs.World.new()
        local components = {}

        for i = 1, 9 do
            local id = world:component()
            components[i] = id
        end
        local e = world:entity()
        for i, id in components do
            world:set(e, id, 13^i)
        end

        for entity, a, b, c, d, e, f, g, h, i in world:query(unpack(components)) do
            CHECK(a == 13^1)
            CHECK(b == 13^2)
            CHECK(c == 13^3)
            CHECK(d == 13^4)
            CHECK(e == 13^5)
            CHECK(f == 13^6)
            CHECK(g == 13^7)
            CHECK(h == 13^8)
            CHECK(i == 13^9)
        end
    end

   	do CASE "should be able to get next results"
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

  		local q = world:query(A):drain()

  		local e, data = q.next()
  		while e do
            if e == eA then
                CHECK(data)
            elseif e == eAB then
                CHECK(data)
            else
                CHECK(false)
            end

 			e, data = q.next()
  		end
        CHECK(true)
   	end

	do CASE("should query all matching entities when irrelevant component is removed")
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

	do CASE("should query all entities without B")
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

	do CASE("should allow querying for relations")
		local world = jecs.World.new()
		local Eats = world:entity()
		local Apples = world:entity()
		local bob = world:entity()

		world:set(bob, pair(Eats, Apples), true)
		for e, bool in world:query(pair(Eats, Apples)) do
			CHECK(e == bob)
			CHECK(bool)
		end
	end

	do CASE("should allow wildcards in queries")
		local world = jecs.World.new()
		local Eats = world:entity()
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

	do CASE("should match against multiple pairs")
		local world = jecs.World.new()
		local Eats = world:entity()
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

	do CASE "should only relate alive entities"
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

	do CASE("should error when setting invalid pair")
		local world = jecs.World.new()
		local Eats = world:entity()
		local Apples = world:entity()
		local bob = world:entity()

		world:delete(Apples)

		world:set(bob, pair(Eats, Apples), "bob eats apples")
	end

	do CASE("should find target for ChildOf")
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

	do CASE "despawning while iterating"
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

	do CASE "iterator invalidation"
		do CASE "adding"
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

		do CASE "spawning"
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
				local e = world:entity()
				world:add(e, A)
				world:add(e, B)
				count += 1
			end

			CHECK(count == 3)
		end
	end

	do CASE "should not find any entities"
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

    do CASE "Empty Query"
        do
            local world = jecs.World.new()
      		local A = world:component()
      		local B = world:component()

      		local e1 = world:entity()
      		world:add(e1, A)

      		local query = world:query(B)
      		CHECK(query:next() == nil)
      		CHECK(query:replace() == nil)
      		CHECK(query:without() == query)
        end

        do
           	local world = jecs.World.new()
    		local A = world:component()
    		local B = world:component()

    		local e1 = world:entity()
    		world:add(e1, A)

    		local count = 0
    		for id in world:query(B) do
    			count += 1
    		end

    		CHECK(count == 0)
        end
    end

    do CASE "replace"
        local world = jecs.World.new()
  		local A = world:component()
  		local B = world:component()
   	    local C = world:component()

  		local e = world:entity()
  		world:set(e, A, 1)
  		world:set(e, B, true)
  		world:set(e, C, "hello ")

  		world:query(A, B, C):replace(function(a, b, c)
  		    return a * 2, not b, c.."world"
  		end)

  		CHECK(world:get(e, A) == 2)
  		CHECK(world:get(e, B) == false)
  		CHECK(world:get(e, C) == "hello world")
    end

    do CASE "without"
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

TEST("world:clear()", function()
    do CASE("should remove its components")
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
end)

TEST("world:has()", function()
    do CASE "should find Tag on entity"
        local world = jecs.World.new()

        local Tag = world:component()

        local e = world:entity()
        world:add(e, Tag)

        CHECK(world:has(e, Tag))
    end
end)

TEST("world:component()", function()
    do CASE "only components should have EcsComponent trait"
        local world = jecs.World.new() :: World
    	local A = world:component()
    	local e = world:entity()

        CHECK(world:has(A, jecs.Component))
        CHECK(not world:has(e, jecs.Component))
	end
end)

TEST("world:delete", function()
    do CASE("should allow deleting components")
		local world = jecs.World.new()

		local Health = world:entity()
		local Poison = world:component()

		local id = world:entity()
		world:set(id, Poison, 5)
		world:set(id, Health, 50)
		local id1 = world:entity()
		world:set(id1, Poison, 500)
		world:set(id1, Health, 50)

		world:delete(id)

		CHECK(world:get(id, Poison) == nil)
		CHECK(world:get(id, Health) == nil)
		CHECK(world:get(id1, Poison) == 500)
		CHECK(world:get(id1, Health) == 50)
	end
end)

type Tracker<T> = { track: (world: World, fn: (changes: {
        added: () -> () -> (number, T),
        removed: () -> () -> number,
        changed: () -> () -> (number, T, T)
    }) -> ()) -> ()
}

type Entity<T = any> = number & { __nominal_type_dont_use: T }

local function diff(a, b)
    local size = 0
    for k, v in a do
        if b[k] ~= v then
            return true
        end
        size += 1
    end
    for k, v in b do
        size -= 1
    end

    if size ~= 0 then
        return true
    end

    return false
end

local function ChangeTracker<T>(world, T: Entity<T>): Tracker<T>
    local PreviousT = jecs.pair(jecs.Rest, T)
    local add = {}
    local added
    local removed
    local is_trivial

    local function changes_added()
        added = true
        local q = world:query(T):without(PreviousT):drain()
        return function()
            local id, data = q.next()
            if not id then
                return nil
            end

            is_trivial = typeof(data) ~= "table"

            add[id] = data

            return id, data
        end
    end

    local function changes_changed()
        local q = world:query(T, PreviousT):drain()

        return function()
            local id, new, old = q.next()
            while true do
                if not id then
                    return nil
                end

                if not is_trivial then
                    if diff(new, old) then
                        break
                    end
                elseif new ~= old then
                    break
                end

                id, new, old = q.next()
            end

            add[id] = new

            return id, old, new
        end
    end

    local function changes_removed()
        removed = true

        local q = world:query(PreviousT):without(T):drain()
        return function()
            local id = q.next()
            if id then
                world:remove(id, PreviousT)
            end
            return id
        end
    end

    local changes = {
        added = changes_added,
        changed = changes_changed,
        removed = changes_removed,
    }

    local function track(fn)
        added = false
        removed = false

        fn(changes)

        if not added then
            for _ in changes_added() do
            end
        end

        if not removed then
            for _ in changes_removed() do
            end
        end

        for e, data in add do
            world:set(e, PreviousT, if is_trivial then data else table.clone(data))
        end
    end

    local tracker = { track = track }

    return tracker
end
TEST("changetracker:track()", function()
    local world = jecs.World.new()

    do CASE "added"
        local Test = world:component() :: Entity<{ foo: number }>
        local TestTracker = ChangeTracker(world, Test)

        local e1 = world:entity()
        local data = { foo = 11 }
        world:set(e1, Test, data)

        TestTracker.track(function(changes)
            local added = 0
      		for e, test in changes.added() do
                added+=1
                CHECK(test == data)
      		end
      		for e, old, new in changes.changed() do
                CHECK(false)
      		end
      		for e in changes.removed() do
                CHECK(false)
      		end
            CHECK(added == 1)
        end)
    end
    do CASE "changed"
        local Test = world:component() :: Entity<{ foo: number }>
        local TestTracker = ChangeTracker(world, Test)

        local data = { foo = 11 }
        local e1 = world:entity()
        world:set(e1, Test, data)

        TestTracker.track(function(changes)
        end)

        data.foo += 1

        TestTracker.track(function(changes)
            for _ in changes.added() do
                CHECK(false)
            end
            local changed = 0
            for e, old, new in changes.changed() do
                CHECK(e == e1)
                CHECK(new == data)
                CHECK(old ~= new)
                CHECK(diff(new, old))
                changed +=1
            end
            CHECK(changed == 1)
        end)
    end
    do CASE "removed"
        local Test = world:component() :: Entity<{ foo: number }>
        local TestTracker = ChangeTracker(world, Test)

        local data = { foo = 11 }
        local e1 = world:entity()
        world:set(e1, Test, data)

        TestTracker.track(function(changes)
        end)

        world:remove(e1, Test)

        TestTracker.track(function(changes)
            for _ in changes.added() do
                CHECK(false)
            end
            for _ in changes.changed() do
                CHECK(false)
            end
            local removed = 0
            for e in changes.removed() do
                removed += 1
                CHECK(e == e1)
            end
            CHECK(removed == 1)
        end)
    end

    do CASE "multiple change trackers"
        local A = world:component()
        local B = world:component()
        local trackerA = ChangeTracker(world, A)
        local trackerB = ChangeTracker(world, B)

        local e1 = world:entity()
        world:set(e1, A, "a1")
        local e2 = world:entity()
        world:set(e2, B, "b1")

        trackerA.track(function() end)
        trackerB.track(function() end)

        world:set(e2, B, "b2")
        trackerA.track(function(changes)
            for _, old, new in changes.changed() do
            end
        end)
        trackerB.track(function(changes)
            for _, old, new in changes.changed() do
                CHECK(new == "b2")
            end
        end)

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
            CHECK(data == 1)
        end)
        world:set(e1, Number, 1)
    end

    do CASE "OnRemove"
        local world = jecs.World.new()
        local A = world:component()
        local e1 = world:entity()
        world:add(e1, A)
        world:set(A, jecs.OnRemove, function(entity)
            CHECK(e1 == entity)
            CHECK(world:has(e1, A))
        end)
        world:remove(e1, A)
        CHECK(not world:has(e1, A))
    end

end)
FINISH()
