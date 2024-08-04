local ReplicatedStorage = game:GetService("ReplicatedStorage")

local std = require(ReplicatedStorage.std)
local world = std.world

local cts = std.components

local Model = cts.Model
local Transform = cts.Transform

local function move(dt: number)
    -- for i, archetype in world:query(Transform, Model):archetypes() do
    --     local columns = archetype.columns
    --     local records = archetype.records
    --     local M = columns[records[Model].column]
    --     local CF = columns[records[Transform].column]

    --     for row, entity in archetype.entities do
    --         local model, cf = M[row], CF[row]

    --         model.PrimaryPart.CFrame = cf
    --     end
    -- end
    for _, cf, model in world:query(Transform, Model) do
        model.PrimaryPart.CFrame = cf
    end
end

return move
