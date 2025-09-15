local jecs = require("@jecs")
local testkit = require("@testkit")
local test = testkit.test()
local CASE, TEST, FINISH, CHECK = test.CASE, test.TEST, test.FINISH, test.CHECK
local FOCUS = test.FOCUS
local ob = require("@addons/ob")

TEST("addons/ob", function()
	local world = jecs.world()
	do CASE "Should support query:without()"
		local A = world:component()
		local B = world:component()

		local c = 1
		local monitor = ob.monitor(world:query(A):without(B))
		monitor.added(function()
			c += 1
		end)
		monitor.removed(function()
			c += 1
		end)

		local child = world:entity()
		world:add(child, B)
		CHECK(c==1)
		world:add(child, A)
		CHECK(c==1)
		world:remove(child, B)
		CHECK(c==2)
		world:remove(child, A)
		CHECK(c==3)
	end

	do CASE "monitors should accept pairs"
		local A = world:component()
		local B = world:component()

		local c = 1
		local monitor = ob.monitor(world:query(jecs.pair(A, B)))
		monitor.added(function()
			c += 1
		end)
		monitor.removed(function()
			c += 1
		end)

		local child = world:entity()
		world:add(child, jecs.pair(A, B))
		CHECK(c == 2)

		world:remove(child, jecs.pair(A, B))
		CHECK(c == 3)
	end

	do CASE "Ensure ordering between signals and observers"
		local A = world:component()
		local B = world:component()

		local count = 1
		local function counter()
			count += 1
		end

		ob.observer(world:query(A, B), counter)

		world:added(A, counter)
		world:added(A, counter)

		for _ in world:query(A) do

		end

		local e = world:entity()
		world:add(e, A)
		CHECK(count == 3)

		world:add(e, B)
		CHECK(count == 4)
	end

	do CASE "Rematch entities in observers"
		local A = world:component()

		local count = 1
		local function counter()
			count += 1
		end

		ob.observer(world:query(A), counter)

		local e = world:entity()
		world:set(e, A, false)
		CHECK(count == 2)
		world:remove(e, A)
		CHECK(count == 2)
		world:set(e, A, false)
		CHECK(count == 3)
		world:set(e, A, false)
		CHECK(count == 4)
	end

	do CASE "Don't report changed components in monitor"
		local A = world:component()
		local count = 1
		local function counter()
			count += 1
		end

		local monitor = ob.monitor(world:query(A))
		monitor.added(counter)
		monitor.removed(counter)

		local e = world:entity()
		world:set(e, A, false)
		CHECK(count == 2)
		world:remove(e, A)
		CHECK(count == 3)
		world:set(e, A, false)
		CHECK(count == 4)
		world:set(e, A, false)
		CHECK(count == 4)
	end

	do CASE "Call off pairs"
		local A = world:component()

		local callcount = 1
		world:added(A, function(entity)
			callcount += 1
		end)
		world:added(A, function(entity)
			callcount += 1
		end)

		local e = world:entity()
		local e2 = world:entity()

		world:add(e2, jecs.pair(A, e))
		world:add(e, jecs.pair(A, e2))
		CHECK(callcount == 1 + 2 * 2)
	end
end)

return FINISH()
