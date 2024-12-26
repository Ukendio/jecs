local ReplicatedStorage = game:GetService("ReplicatedStorage")
local std = ReplicatedStorage.std
local world = require(std.world)

local A = world:component()
local B = world:component()
local C = world:component()
local D = world:component()

local function flip() 
    return math.random() >= 0.15
end

for i = 1, 2^8 do 
    local e = world:entity()
    if flip() then 
        world:set(e, A, true)
    end
    if flip() then 
        world:set(e, B, true)
    end
    if flip() then 
        world:set(e, C, true)
    end
    if flip() then 
        world:set(e, D, true)
    end
end

local function uncached() 
    for _ in world:query(A, B, C, D) do 
    end
end

local q = world:query(A, B, C, D):cached()
local function cached() 
    for _ in q do 
    end
end

local scheduler = require(std.scheduler)
scheduler.SYSTEM(uncached)
scheduler.SYSTEM(cached)
return 0