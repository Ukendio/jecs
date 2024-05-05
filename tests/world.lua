local testkit = require("../testkit")
local jecs = require("../lib/init")

local TEST, CASE, CHECK, FINISH, SKIP = testkit.test()

local N = 10

TEST("world", function() 
    do CASE "should be iterable" 
        local world = jecs.World.new()
        local A = world:component()
        local B = world:component()
         
        local eA = world:entity()
        world:set(eA, A, true)
        local eB = world:entity()
        world:set(eB, B, true)
        local eAB = world:entity()
        world:set(eAB, A, true)
        world:set(eAB, B, true)

        local count = 0
        for id, data in world do
            count += 1
            if id == eA then
                CHECK(data[A] == true)
                CHECK(data[B] == nil)
            elseif id == eB then
                CHECK(data[A] == nil)
                CHECK(data[B] == true)
            elseif id == eAB then
                CHECK(data[A] == true)
                CHECK(data[B] == true)
            else
                error("unknown entity", id)
            end
        end

        CHECK(count == 3)
    end

    do CASE "should query all matching entities"

        local world = jecs.World.new()
        local A = world:component()
        local B = world:component()

        local entities = {}
        for i = 1, N do
            local id = world:entity()

            world:set(id, A, true)
            if i > 5 then world:set(id, B, true) end
            entities[i] = id
        end

        for id in world:query(A) do
            table.remove(entities, CHECK(table.find(entities, id)))
        end

        CHECK(#entities == 0)

    end

    do CASE "should query all matching entities when irrelevant component is removed"

        local world = jecs.World.new()
        local A = world:component()
        local B = world:component()

        local entities = {}
        for i = 1, N do
            local id = world:entity()

            world:set(id, A, true)
            world:set(id, B, true)
            if i > 5 then world:remove(id, B, true) end
            entities[i] = id
        end

        local added = 0
        for id in world:query(A) do
            added += 1
            table.remove(entities, CHECK(table.find(entities, id)))
        end

        CHECK(added == N)
    end

    do CASE "should query all entities without B"

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

    do CASE "should allow setting components in arbitrary order" 
        local world = jecs.World.new()

        local Health = world:entity()
        local Poison = world:component()

        local id = world:entity()
        world:set(id, Poison, 5)
        world:set(id, Health, 50)

        CHECK(world:get(id, Poison) == 5)
    end

    do CASE "Should allow deleting components" 
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

FINISH()