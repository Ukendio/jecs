--!optimize 2
--!native

local testkit = require('../testkit')
local BENCH, START = testkit.benchmark()
local function TITLE(title: string)
    print()
    print(testkit.color.white(title))
end

local jecs = require("../lib/init")
local ecs = jecs.World.new()


type i53 = number

do TITLE (testkit.color.white_underline("query"))
    do TITLE "one component in common"
        local function view_bench(
            world: jecs.World,
            A: i53, B: i53, C: i53, D: i53, E: i53, F: i53, G: i53, H: i53
        )

            BENCH("1 component", function()
                for _ in world:query(A) do end
            end)

            BENCH("2 component", function()
                for _ in world:query(A, B) do end
            end)

            BENCH("4 component", function()
                for _ in world:query(A, B, C, D) do 
                end
            end)

            BENCH("8 component", function()
                for _ in world:query(A, B, C, D, E, F, G, H) do end
            end)
        end

        local D1 = ecs:component()
        local D2 = ecs:component()
        local D3 = ecs:component()
        local D4 = ecs:component()
        local D5 = ecs:component()
        local D6 = ecs:component()
        local D7 = ecs:component()
        local D8 = ecs:component()

        local function flip() 
            return math.random() >= 0.155
        end

        local added = 0
        for i = 1, 2^16-2 do 
            local entity = ecs:entity()

            local combination = ""

            if flip() then 
                combination ..= "B"
                ecs:set(entity, D2, true)
            end
            if flip() then 
                combination ..= "C"
                ecs:set(entity, D3, true)
            end
            if flip() then 
                combination ..= "D"
                ecs:set(entity, D4, true)
            end
            if flip() then 
                combination ..= "E"
                ecs:set(entity, D5, true)
            end
            if flip() then 
                combination ..= "F"
                ecs:set(entity, D6, true)
            end
            if flip() then 
                combination ..= "G"
                ecs:set(entity, D7, true)
            end
            if flip() then 
                combination ..= "H"
                ecs:set(entity, D8, true)

            end

            if #combination == 7 then 
                added += 1
                ecs:set(entity, D1, true)
            end
        end

        print("entities with common component", added)

        view_bench(ecs, D1, D2, D3, D4, D5, D6, D7, D8)
    end
end