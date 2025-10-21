local jecs = require("@jecs")
local testkit = require("@testkit")
local test = testkit.test()
local CASE, TEST, FINISH, CHECK = test.CASE, test.TEST, test.FINISH, test.CHECK
local FOCUS = test.FOCUS
local ob = require("@addons/ob")

TEST("addons/ob::observer", function()
	local world = jecs.world()
	do CASE [[should not invoke callbacks with a related but non-queried pair that
		while the entity still matches against the query]]
		local A = world:component()
		local B = world:component()
		local C = world:component()

		local c = 1

		ob.observer(world:query(jecs.pair(A, B)), function()
			c+=1
		end)

		local e = world:entity()
		CHECK(c==1)
		world:add(e, jecs.pair(A, B))
		CHECK(c==2)
		world:add(e, jecs.pair(A, C))
		print(c)
		CHECK(c==2)
	end

	do CASE "should match against archetypes that were already created"
		local A = world:component()

		local e1 = world:entity()
		world:add(e1, A)

		local c = 1
		ob.observer(world:query(A), function()
			c+=1
		end)

		world:remove(e1, A)
		world:add(e1, A)
		CHECK(c==2)
	end

	do CASE "Should enter observer at query:without(pair(R, t1)) when adding pair(R, t2)"
		local A = world:component()
		local B = world:component()
		local C = world:component()
		local D = world:component()

		local e = world:entity()
		world:add(e, A)
		world:add(e, jecs.pair(B, D))

		local c = 1

		ob.observer(world:query(A):without(jecs.pair(B, C)), function()
			c += 1
		end)

		local child = world:entity()
		world:add(child, A)
		CHECK(c==2)
		world:add(child, jecs.pair(B, D))
		CHECK(c==2)
		world:add(child, jecs.pair(B, C))
		CHECK(c==2)
	end

	do CASE "Should enter observer at query:without(pair(R, t1)) when removing pair(R, t1)"
		local A = world:component()
		local B = world:component()
		local C = world:component()
		local D = world:component()

		local e = world:entity()
		world:add(e, A)
		world:add(e, jecs.pair(B, D))

		local c = 1
		ob.observer(world:query(A):without(jecs.pair(B, D)), function()
			c += 1
		end)

		local child = world:entity()
		world:add(child, jecs.pair(B, C))
		world:add(child, jecs.pair(B, D))
		CHECK(c==1)
		world:add(child, A)
		CHECK(c==1)
		world:remove(child, jecs.pair(B, C))
		CHECK(c==1)
		world:add(child, jecs.pair(B, C))
		CHECK(c==1)
		world:remove(child, jecs.pair(B, D))
		CHECK(c==2)
		world:add(child, jecs.pair(B, D))
		CHECK(c==2)
		world:remove(child, jecs.pair(B, C))
		CHECK(c==2)
		world:remove(child, jecs.pair(B, D))
		CHECK(c==3)
	end

	do CASE "Should enter observer at query:without(pair(R, *)) when adding pair(R, t1)"
		local A = world:component()
		local B = world:component()
		local C = world:component()
		local D = world:component()

		local c = 1
		ob.observer(world:query(A):without(jecs.pair(B, jecs.w)), function() c+= 1 end)

		local child = world:entity()
		world:add(child, A)
		CHECK(c==2)
		world:add(child, jecs.pair(B, D))
		CHECK(c==2)
		world:add(child, jecs.pair(B, C))
		CHECK(c==2)
	end

	do CASE "Should enter observer at query:without(t1) when removing t1"
		local A = world:component()
		local B = world:component()

		local c = 1
		ob.observer(world:query(A):without(B), function() c+= 1 end)

		local child = world:entity()
		world:add(child, B)
		CHECK(c==1)
		world:add(child, A)
		CHECK(c==1)
		world:remove(child, B)
		CHECK(c==2)
		world:remove(child, A)
		CHECK(c==2)
	end

	do CASE "observers should accept pairs"
		local A = world:component()
		local B = world:component()

		local c = 1
		ob.observer(world:query(jecs.pair(A, B)), function() c+= 1 end)

		local child = world:entity()
		world:add(child, jecs.pair(A, B))
		CHECK(c == 2)

		world:remove(child, jecs.pair(A, B))
		CHECK(c == 2)
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

FOCUS()
TEST("addons/ob::monitor", function()
	local world = jecs.world()

	do CASE [[should not invoke monitor.added callback unless it wasn't apart
	of the monitor]]
		local A = world:component()
		local B = world:component()
		local C = world:component()

		local monitor = ob.monitor(world:query(A):without(B, C))
		local c = 0
		monitor.added(function()
			c += 1
		end)

		local e = world:entity()
		world:add(e, A)
		CHECK(c==1)
		world:add(e, B)
		world:add(e, C)
		-- left
		CHECK(c==1)

		world:remove(e, B)
		world:remove(e, C)
		-- re-enters once
		CHECK(c==2)

		world:remove(e, B)
		CHECK(c==2)
	end

	do CASE "deleted entity should only exit monitor once"
		local A = world:component()
		local B = world:component()

		local Destroy = world:entity()

		local c = 0

		local monitor = ob.monitor(world:query(A, B):without(Destroy))

		monitor.added(function()
			print("enter")
		end)
		monitor.removed(function()
			c += 1
		end)


		local e = world:entity()
		world:add(e, A)
		world:add(e, B)

		world:add(e, Destroy)

		world:delete(e)
		print(c)
		CHECK(c==1)
	end

	do CASE [[should not invoke callbacks with a related but non-queried pair that
		while the entity still matches against the query]]
		local A = world:component()
		local B = world:component()
		local C = world:component()

		local c = 1

		local monitor = ob.monitor(world:query(jecs.pair(A, B)))

		monitor.added(function()
			c += 1
		end)


		local e = world:entity()
		CHECK(c==1)
		world:add(e, jecs.pair(A, B))
		CHECK(c==2)
		world:add(e, jecs.pair(A, C))
		CHECK(c==2)
	end
	do CASE "should match against archetypes that were already created"
		local A = world:component()

		local e1 = world:entity()
		world:add(e1, A)

		local monitor = ob.monitor(world:query(A))
		local c = 1
		monitor.added(function()
			c += 1
		end)

		world:remove(e1, A)
		world:add(e1, A)
		CHECK(c==2)
	end

	do CASE "Should enter monitor at query:without(pair(R, t1)) when adding pair(R, t2)"
		local A = world:component()
		local B = world:component()
		local C = world:component()
		local D = world:component()

		local e = world:entity()
		world:add(e, A)
		world:add(e, jecs.pair(B, D))

		local c = 1
		local r = 1
		local monitor = ob.monitor(world:query(A):without(jecs.pair(B, C)))
		monitor.added(function()
			c += 1
		end)
		monitor.removed(function()
			r += 1
		end)

		local child = world:entity()
		world:add(child, A)
		CHECK(c==2)
		world:add(child, jecs.pair(B, D))
		CHECK(c==2)
		CHECK(r==1)
		world:add(child, jecs.pair(B, C))
		CHECK(c==2)
		CHECK(r==2)
	end

	do CASE "Should enter monitor at query:without(pair(R, t1)) when removing pair(R, t1)"
		local A = world:component()
		local B = world:component()
		local C = world:component()
		local D = world:component()

		local e = world:entity()
		world:add(e, A)
		world:add(e, jecs.pair(B, D))

		local c = 1
		local r = 1
		local monitor = ob.monitor(world:query(A):without(jecs.pair(B, D)))
		monitor.added(function()
			c += 1
		end)
		monitor.removed(function()
			r += 1
		end)

		local child = world:entity()
		world:add(child, jecs.pair(B, C))
		world:add(child, jecs.pair(B, D))
		CHECK(c==1)
		world:add(child, A)
		CHECK(c==1)
		world:remove(child, jecs.pair(B, C))
		CHECK(c==1)
		world:add(child, jecs.pair(B, C))
		CHECK(c==1)
		world:remove(child, jecs.pair(B, D))
		CHECK(c==2)
		world:add(child, jecs.pair(B, D))
		CHECK(c==2)
		CHECK(r==2)
		world:remove(child, jecs.pair(B, C))
		CHECK(c==2)
		CHECK(r==2)
		world:remove(child, jecs.pair(B, D))
		CHECK(c==3)
		CHECK(r==2)
	end

	do CASE "Should enter monitor at query:without(pair(R, *)) when adding pair(R, t1)"
		local A = world:component()
		local B = world:component()
		local C = world:component()
		local D = world:component()

		local c = 1
		local r = 1
		local monitor = ob.monitor(world:query(A):without(jecs.pair(B, jecs.w)))
		monitor.added(function()
			c += 1
		end)
		monitor.removed(function()
			r += 1
		end)

		local child = world:entity()
		world:add(child, A)
		CHECK(c==2)
		world:add(child, jecs.pair(B, D))
		CHECK(c==2)
		CHECK(r==2)
		world:add(child, jecs.pair(B, C))
		CHECK(c==2)
		CHECK(r==2)
	end

	do CASE "Should enter monitor at query:without(t1) when removing t1"
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
end)

return FINISH()
