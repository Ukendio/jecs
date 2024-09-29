local jecs = require("@jecs")
local world = jecs.World.new()

local Model = world:component()

-- It is important to define hooks for the component before the component is ever used
-- otherwise the hooks will never invoke!
world:set(Model, jecs.OnRemove, function(entity)
    -- OnRemove is invoked before the component and its value is removed
    -- which provides a stable reference to the entity at deletion.
    -- This means that it is safe to retrieve the data inside of a hook
    local model = world:get(entity, Model)
    model:Destroy()
end)

world:set(Model, jecs.OnSet, function(entity, model)
    -- OnSet is invoked after the data has been assigned.
    -- It also returns the data for faster access.
    -- There may be some logic to do some side effects on reassignments
    model:SetAttribute("entityId", entity)
end)
