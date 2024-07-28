local jecs = require("@jecs")
local testkit = require("@testkit")
local __ = jecs.Wildcard
local ECS_ID, ECS_GENERATION = jecs.ECS_ID, jecs.ECS_GENERATION
local ECS_GENERATION_INC = jecs.ECS_GENERATION_INC
local IS_PAIR = jecs.IS_PAIR
local pair = jecs.pair
local getAlive = jecs.entity_index_get_alive
local ecs_pair_relation = jecs.ecs_pair_relation
local ecs_pair_object = jecs.ecs_pair_object

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
local N = 10

type World = jecs.WorldShim

TEST("world", function()
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
	do CASE("should find every component id")
		local world = jecs.World.new() :: World
		local A = world:component()
		local B = world:component()
		world:entity()
		world:entity()
		world:entity()

		local count = 0
		for componentId in world:query(jecs.Component) do
			if componentId ~= A and componentId ~= B then
				error("found entity")
			end
			count += 1
		end

		CHECK(count == 2)
	end

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

	do CASE("should drain query while iterating")
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

		local q = world:query(A)

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

	do CASE("should be able to get next results")
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

		local q = world:query(A)

		local e, data = q:next()
		while e do
			CHECK(
				if e == eA then data == true
				elseif e == eAB then data == true
				else false
			)
			e, data = q:next()
		end
	end

	do CASE("should query all matching entities")
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

	do CASE("should allow setting components in arbitrary order")
		local world = jecs.World.new()

		local Health = world:entity()
		local Poison = world:component()

		local id = world:entity()
		world:set(id, Poison, 5)
		world:set(id, Health, 50)

		CHECK(world:get(id, Poison) == 5)
	end

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

	do CASE("should increment generation")
		local world = jecs.World.new()
		local e = world:entity()
		CHECK(ECS_ID(e) == 1 + jecs.Rest)
		CHECK(getAlive(world.entityIndex, ECS_ID(e)) == e)
		CHECK(ECS_GENERATION(e) == 0) -- 0
		e = ECS_GENERATION_INC(e)
		CHECK(ECS_GENERATION(e) == 1) -- 1
	end

	do CASE("should get alive from index in the dense array")
		local world = jecs.World.new()
		local _e = world:entity()
		local e2 = world:entity()
		local e3 = world:entity()

		CHECK(IS_PAIR(world:entity()) == false)

		local pair = pair(e2, e3)
		CHECK(IS_PAIR(pair) == true)

		CHECK(ecs_pair_relation(world.entityIndex, pair) == e2)
		CHECK(ecs_pair_object(world.entityIndex, pair) == e3)
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

	do CASE "should be able to add/remove matching entity during iteration"
		local world = jecs.World.new()
		local Name = world:component()
		for i = 1, 5 do
			local e = world:entity()
			world:set(e, Name, tostring(e))
		end
		local count = 0
		for id, name in world:query(Name) do
			count += 1
			CHECK(id == tonumber(name))

			world:remove(id, Name)
			local e = world:entity()
			world:set(e, Name, tostring(e))
		end
		CHECK(count == 5)
	end

	do CASE "should allow adding a matching entity during iteration"
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


	do CASE "should not iterate same entity when adding component"
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

	do CASE "should replace component data"
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

	do CASE "should not iterate when nothing matches query"
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

	do CASE "should return nothing for empty iteration"
		local world = jecs.World.new()
		local A = world:component()
		local B = world:component()

		local e1 = world:entity()
		world:add(e1, A)

		local query = world:query(B)
		CHECK(query.next() == nil)
		CHECK(query.replace() == nil)
	end

	do CASE "should properly handle query:without for empty iteration"
		local world = jecs.World.new()
		local A = world:component()
		local B = world:component()

		local e1 = world:entity()
		world:add(e1, A)

		local query = world:query(B)
		CHECK(query == query:without())
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

    do CASE "should find Tag on entity"
        local world = jecs.World.new()

        local Tag = world:component()

        local e = world:entity()
        world:add(e, Tag)

        CHECK(world:has(e, Tag))
    end

    do CASE "should return false when missing one tag"
           local world = jecs.World.new()

           local A = world:component()
           local B = world:component()
           local C = world:component()
           local D = world:component()

           local e = world:entity()
           world:add(e, A)
           world:add(e, C)
           world:add(e, D)

           CHECK(world:has(e, A, B, C, D) == false)
       end

end)

type Tracker<T> = { track: (world: World, fn: (changes: {
        added: () -> () -> (number, T),
        removed: () -> () -> number,
        changed: () -> () -> (number, T, T)
    }) -> ()) -> ()
}

type Entity<T = any> = number & { __nominal_type_dont_use: T }

local ChangeTracker: <T>(world: World, component: Entity<T>) -> Tracker<T>

do
    local world
    local T
    local PreviousT
    local add
    local is_trivial
    local added
    local removed

    local function changes_added()
        added = true
        local q = world:query(T):without(PreviousT)
        return function()
            local id, data = q:next()
            if not id then
                return nil
            end

            if is_trivial == nil then
                isTrivial = typeof(data) ~= "table"
            end

            if not isTrivial then
                data = table.clone(data)
            end

            add[id] = data
            return id, data
        end
    end

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

    local function changes_changed()
        local q = world:query(T, PreviousT)

        return function()
            local id, new, old = q:next()
            while true do
                if not id then
                    return nil
                end

                if isTrivial and new ~= old then
                elseif diff(new, old) then
                    break
                end

                id, new, old = q:next()
            end

            add[id] = new

            return id, old, new
        end
    end

    local function changes_removed()
        removed = true

        local q = world:query(PreviousT):without(T)
        return function()
            local id = q:next()
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
        added = true
        removed = true

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
            world:set(e, PreviousT, if isTrivial then data else table.clone(data))
        end
    end

    local tracker = { track = track }

    function ChangeTracker<T>(worldToTrack, component: Entity<T>): Tracker<T>
        world = worldToTrack
        T = component
        -- We just use jecs.Rest because people will probably not use it anyways
        PreviousT = jecs.pair(jecs.Rest, T)
        add = {}

        return tracker
    end
end

TEST("changetracker", function()
    local world = jecs.World.new()

	do CASE "should allow change tracking"
        local Test = world:component() :: Entity<{ foo: number }>
        local TestTracker = ChangeTracker(world, Test)

		local e = world:entity()
		world:set(e, Test, { foo = 11 })

        TestTracker.track(function(changes)
            local added = 0
            local changed = 0
            local removed = 0
      		for e, data in changes.added() do
                added+=1
      		end
      		for e, old, new in changes.changed() do
                changed+=1
      		end
      		for e in changes.removed() do
                removed+=1
      		end
            CHECK(added == 1)
            CHECK(changed == 0)
            CHECK(removed == 0)
        end)

        for e, test in world:query(Test) do
    	    test.foo = test.foo + 1
     	end

        TestTracker.track(function(changes)
            local added = 0
            local changed = 0
            local removed = 0

    		for e, data in changes.added() do
                added+=1
    		end
    		for e, old, new in changes.changed() do
                changed+=1
    		end
    		for e in changes.removed() do
                removed+=1
    		end

            CHECK(added == 0)
            CHECK(changed == 1)
            CHECK(removed == 0)
        end)

        world:remove(e, Test)

        TestTracker.track(function(changes)
            local added = 0
            local changed = 0
            local removed = 0
       	    for e, data in changes.added() do
                added+=1
    		end
    		for e, old, new in changes.changed() do
                changed+=1
    		end
    		for e in changes.removed() do
                removed+=1
    		end
            CHECK(added == 0)
            CHECK(changed == 0)
            CHECK(removed == 1)
        end)
    end
end)

FINISH()
