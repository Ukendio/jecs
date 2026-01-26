local Spring_Vector3 = require("@modules/Spring/vector3")
local Spring_Generic = require("@modules/Spring/generic")

local spring = Spring_Vector3.create(1, 1, vector.create(0, 0, 0), vector.create(1, 1, 1))

local p = Spring_Vector3.step(spring, 1/60) -- You can also supplement 0 for the deltatime and it will just give you the value it is on right now
print(p)
print(Spring_Vector3.can_sleep(spring))

-- This generic spring interface allows you to step any spring which can be
-- useful if you would like a single homogenous system to update all scheduled
-- springs
Spring_Generic.step(spring, 1/60)


