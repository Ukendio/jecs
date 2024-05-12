local testkit = require("../testkit")
local jecs = require("../lib/init")
local ECS_ID, ECS_GENERATION = jecs.ECS_ID, jecs.ECS_GENERATION
local ECS_GENERATION_INC = jecs.ECS_GENERATION_INC
local IS_PAIR = jecs.IS_PAIR
local ECS_PAIR = jecs.ECS_PAIR
local getAlive = jecs.getAlive
local ecs_get_source = jecs.ecs_get_source
local ecs_get_target = jecs.ecs_get_target
local REST = 256 + 4

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
            end
        end

        -- components are registered in the entity index as well 
        -- so this test has to add 2 to account for them
        CHECK(count == 3 + 2)
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
        local C = world:component()

        local entities = {}
        for i = 1, N do
            local id = world:entity()

            -- specifically put them in disorder to track regression
            -- https://github.com/Ukendio/jecs/pull/15
            world:set(id, B, true)
            world:set(id, A, true)
            if i > 5 then world:remove(id, B) end
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

    do CASE "should allow deleting components" 
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

    do CASE "should allow remove that doesn't exist on entity" 
        local world = jecs.World.new()

        local Health = world:entity()
        local Poison = world:component()

        local id = world:entity()
        world:set(id, Health, 50)
        world:remove(id, Poison)

        CHECK(world:get(id, Poison) == nil)
        CHECK(world:get(id, Health) == 50)
    end

    do CASE "should increment generation" 
        local world = jecs.World.new()
        local e = world:entity()
        CHECK(ECS_ID(e) == 1 + jecs.REST)
        CHECK(getAlive(world.entityIndex, ECS_ID(e)) == e)
        CHECK(ECS_GENERATION(e) == 0) -- 0
        e = ECS_GENERATION_INC(e) 
        CHECK(ECS_GENERATION(e) == 1) -- 1
    end

    do CASE "should get alive from index in the dense array" 
        local world = jecs.World.new()
        local _e = world:entity()
        local e2 = world:entity()
        local e3 = world:entity()

        CHECK(IS_PAIR(world:entity()) == false)

        local pair = ECS_PAIR(e2, e3)
        CHECK(IS_PAIR(pair) == true)
        CHECK(ecs_get_source(world.entityIndex, pair) == e2)
        CHECK(ecs_get_target(world.entityIndex, pair) == e3)
    end

    do CASE "should allow querying for relations" 
        local world = jecs.World.new()
        local Eats = world:entity()
        local Apples = world:entity()
        local bob = world:entity()
        
        world:set(bob, ECS_PAIR(Eats, Apples), true)
        for e in  world:query(ECS_PAIR(Eats, Apples)) do 
            CHECK(e == bob)
        end
    end
    
    do CASE "should allow wildcards in queries" 
        local world = jecs.World.new()
        local Eats = world:entity()
        local Apples = world:entity()
        local bob = world:entity()
        
        world:add(bob, ECS_PAIR(Eats, Apples))
        
        local w = jecs.Wildcard
        for e in world:query(ECS_PAIR(Eats, w)) do 
            CHECK(e == bob)
        end
        for e in world:query(ECS_PAIR(w, Apples)) do 
            CHECK(e == bob)
        end
    end

    do CASE "should match against multiple pairs" 
        local world = jecs.World.new()
        local Eats = world:entity()
        local Apples = world:entity()
        local Oranges =world:entity()
        local bob = world:entity()
        local alice = world:entity()
        
        world:add(bob, ECS_PAIR(Eats, Apples))
        world:add(alice, ECS_PAIR(Eats, Oranges))
        
        local w = jecs.Wildcard
        local count = 0
        for e in world:query(ECS_PAIR(Eats, w)) do 
            count += 1
        end

        CHECK(count == 2)
        count = 0

        for e in world:query(ECS_PAIR(w, Apples)) do 
            count += 1
        end
        CHECK(count == 1)
    end
end)

FINISH()