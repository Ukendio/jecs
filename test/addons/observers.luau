local jecs = require("@jecs")
local testkit = require("@testkit")
local test = testkit.test()
local CASE, TEST, FINISH, CHECK = test.CASE, test.TEST, test.FINISH, test.CHECK
local observers_add = require("@addons/observers")

TEST("addons/observers", function()
	local world = observers_add(jecs.world())

	do CASE "Should work even if set after the component has been used"
		local A = world:component()

		world:set(world:entity(), A, 1)
		local ran = false
		world:added(A, function()
			ran = true
		end)

		local entity = world:entity()
		world:set(entity, A, 2)

		CHECK(ran)
	end

	do CASE "Should not override hook"
		local A = world:component()

		local count = 0
		local function counter()
			count += 1
		end

		world:set(A, jecs.OnAdd, counter)
		world:added(A, counter)
		world:set(world:entity(), A, true)
		CHECK(count == 2)
		world:set(world:entity(), A, true)

		CHECK(count == 4)
	end

	do CASE "Ensure ordering between signals and observers"
		local A = world:component()
		local B = world:component()

		local count = 0
		local function counter()
			count += 1
		end

		world:observer(world:query(A, B), counter)

		world:added(A, counter)
		world:added(A, counter)

		local e = world:entity()
		world:add(e, A)
		CHECK(count == 2)

		world:add(e, B)
		CHECK(count == 3)
	end

	do CASE "Rematch entities in observers"
		local A = world:component()

		local count = 0
		local function counter()
			count += 1
		end

		world:observer(world:query(A), counter)

		local e = world:entity()
		world:set(e, A, true)
		CHECK(count == 1)
		world:remove(e, A)
		CHECK(count == 1)
		world:set(e, A, true)
		CHECK(count == 2)
		world:set(e, A, true)
		CHECK(count == 3)
	end

	do CASE "Don't report changed components in monitor"
		local A = world:component()
		local count = 0
		local function counter()
			count += 1
		end

		world:monitor(world:query(A), counter)

		local e = world:entity()
		world:set(e, A, true)
		CHECK(count == 1)
		world:remove(e, A)
		CHECK(count == 2)
		world:set(e, A, true)
		CHECK(count == 3)
		world:set(e, A, true)
		CHECK(count == 3)
	end

	do CASE "Call on pairs"
		local A = world:component()

		local callcount = 0
		world:added(A, function(entity)
			callcount += 1
		end)
		world:added(A, function(entity)
			callcount += 1
		end)

		local e = world:entity()
		local e1 = world:entity()

		world:add(e1, jecs.pair(A, e))
		world:add(e, jecs.pair(A, e1))
		CHECK(callcount == 4)
	end
end)

return FINISH()
