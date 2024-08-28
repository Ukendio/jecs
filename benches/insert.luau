--!optimize 2
--!native

local testkit = require("@testkit")
local BENCH, START = testkit.benchmark()
local function TITLE(title: string)
print()
print(testkit.color.white(title))
end

local jecs = require("@jecs")

type i53 = number

local N = 1000

do TITLE(testkit.color.white_underline("Jecs insert"))
    local ecs = jecs.World.new()

    local ctypes = {}

    local A = ecs:component()
    local B = ecs:component()
    local C = ecs:component()
    local D = ecs:component()
    local E = ecs:component()
    local F = ecs:component()
    local G = ecs:component()
    local H = ecs:component()
    ecs:add(A, jecs.Tag)
    ecs:add(B, jecs.Tag)
    ecs:add(C, jecs.Tag)
    ecs:add(D, jecs.Tag)
    ecs:add(E, jecs.Tag)
    ecs:add(F, jecs.Tag)
    ecs:add(G, jecs.Tag)
    ecs:add(H, jecs.Tag)


    BENCH("insert 1 components on entity with 16 components", function()
        local entities = {}

        for i = 1, N do
            entities[i] = ecs:entity()
        end

        for _, entity in entities do
            ecs:add(entity, A)
            ecs:add(entity, B)
            ecs:add(entity, C)
            ecs:add(entity, D)
            ecs:add(entity, E)
            ecs:add(entity, F)
            ecs:add(entity, G)
            ecs:add(entity, H)
        end

        for i = 1, N do
            ecs:remove(entities[i], A)
        end

        for i = 1, START(N) do
            local entity = entities[i]
            ecs:add(entity, A)
        end
    end)
end
