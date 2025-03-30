local jecs = require("@jecs")
local observers_add = require("@addons/observers")

local world = jecs.world()
observers_add(world)

local A = world:component()
local B = world:component()
local C = world:component()

world:observer({
	query = world:query(),
	callback = function(entity)
		buf ..= debug.info(2, "sl")
	end
})

local i = 0
world:added(A, function(entity)
	assert(i == 0)
	i += 1
end)
world:added(A, function(entity)
	assert(i == 1)
	i += 1
end)

world:removed(A, function(entity)
	assert(false)
end)

local observer = world:observer({
	query = world:query(A, B),
	callback = function(entity)
		assert(i == 2)
		i += 1
	end
})


local e = world:entity()
world:add(e, A)
assert(i == 2)

world:add(e, B)
assert(i == 3)
