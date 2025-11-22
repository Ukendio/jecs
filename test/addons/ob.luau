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

	do CASE "observer with pair should handle remove and re-add correctly"
		local A = world:component()
		local B = world:component()
		local e1 = world:entity()

		local c = 0
		ob.observer(world:query(jecs.pair(A, e1)), function()
			c += 1
		end)

		local e = world:entity()
		world:add(e, jecs.pair(A, e1))
		CHECK(c == 1)
		world:remove(e, jecs.pair(A, e1))
		CHECK(c == 1)
		world:add(e, jecs.pair(A, e1))
		CHECK(c == 2)
		world:remove(e, jecs.pair(A, e1))
		CHECK(c == 2)
	end

	do CASE "observer with pair should handle set operations correctly"
		local A = world:component()
		local B = world:component()
		local e1 = world:entity()

		local c = 0
		ob.observer(world:query(jecs.pair(A, e1)), function()
			c += 1
		end)

		local e = world:entity()
		world:set(e, jecs.pair(A, e1), true)
		CHECK(c == 1)
		world:set(e, jecs.pair(A, e1), false)
		CHECK(c == 2)
		world:set(e, jecs.pair(A, e1), true)
		CHECK(c == 3)
		world:remove(e, jecs.pair(A, e1))
		CHECK(c == 3)
		world:set(e, jecs.pair(A, e1), true)
		CHECK(c == 4)
	end

	do CASE "observer with wildcard pair should handle operations correctly"
		local A = world:component()
		local B = world:component()
		local e1 = world:entity()
		local e2 = world:entity()

		local c = 0
		ob.observer(world:query(A, jecs.pair(B, jecs.w)), function()
			c += 1
		end)

		local e = world:entity()
		world:add(e, A)
		CHECK(c == 0)
		world:set(e, jecs.pair(B, e1), true)
		CHECK(c == 1)
		world:set(e, jecs.pair(B, e2), false)
		CHECK(c == 2)
		world:remove(e, jecs.pair(B, e1))
		CHECK(c == 2)
		world:remove(e, jecs.pair(B, e2))
		CHECK(c == 2)
	end
end)

TEST("addons/ob::monitor", function()
	local world = jecs.world()

	do CASE [[should not invoke monitor.added callback multiple times in a bulk_move
	]]
		local A = world:component()
		local B = world:component()
		local C = world:component()

		local monitor = ob.monitor(world:query(A, B, C))
		local c = 0
		monitor.added(function()
			c += 1
		end)

		local e = world:entity()
		jecs.bulk_insert(world, e, { A, B, C }, { 1, 2, 3 })
		CHECK(c==1)
	end

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

	do CASE "different entities bulk_insert with same old archetype"
		local A = world:component()
		local B = world:component()
		local C = world:component()

		local monitor = ob.monitor(world:query(A, B, C))
		local c = 0
		monitor.added(function()
			c += 1
		end)

		local e1 = world:entity()
		local e2 = world:entity()

		-- First entity: ROOT_ARCHETYPE -> ABC (triggers, sets last_old_archetype = ROOT_ARCHETYPE)
		jecs.bulk_insert(world, e1, { A, B, C }, { 1, 2, 3 })
		CHECK(c == 1)

		-- Second entity: ROOT_ARCHETYPE -> ABC (same old archetype, but different entity)
		-- Should still trigger even though last_old_archetype == ROOT_ARCHETYPE
		jecs.bulk_insert(world, e2, { A, B, C }, { 4, 5, 6 })
		CHECK(c == 2)
	end

	do CASE "multiple entities bulk_insert pairs with same old archetype"
		local A = world:component()
		local B = world:component()
		local e1 = world:entity()
		local e2 = world:entity()

		local monitor = ob.monitor(world:query(jecs.pair(A, e1), jecs.pair(A, e2)))
		local c = 0
		monitor.added(function()
			c += 1
		end)

		local entity1 = world:entity()
		local entity2 = world:entity()

		-- First entity: ROOT_ARCHETYPE -> pairs (triggers)
		jecs.bulk_insert(world, entity1, { jecs.pair(A, e1), jecs.pair(A, e2) }, { true, true })
		CHECK(c == 1)

		-- Second entity: ROOT_ARCHETYPE -> pairs (same old archetype, different entity)
		-- Should still trigger
		jecs.bulk_insert(world, entity2, { jecs.pair(A, e1), jecs.pair(A, e2) }, { true, true })
		CHECK(c == 2)
	end

	do CASE "entities transition sequentially with same old archetype"
		local A = world:component()
		local B = world:component()
		local C = world:component()

		local monitor = ob.monitor(world:query(A, B, C))
		local c = 0
		monitor.added(function()
			c += 1
		end)

		local e1 = world:entity()
		local e2 = world:entity()
		local e3 = world:entity()

		-- All three entities: ROOT_ARCHETYPE -> ABC
		-- Each should trigger independently
		jecs.bulk_insert(world, e1, { A, B, C }, { 1, 2, 3 })
		CHECK(c == 1)

		jecs.bulk_insert(world, e2, { A, B, C }, { 4, 5, 6 })
		CHECK(c == 2)

		jecs.bulk_insert(world, e3, { A, B, C }, { 7, 8, 9 })
		CHECK(c == 3)
	end

	do CASE "entity transitions after another entity with same old archetype"
		local A = world:component()
		local B = world:component()

		local monitor = ob.monitor(world:query(A, B))
		local c = 0
		monitor.added(function()
			c += 1
		end)

		local e1 = world:entity()
		local e2 = world:entity()

		-- First entity: ROOT_ARCHETYPE -> AB (triggers, sets last_old_archetype = ROOT_ARCHETYPE)
		jecs.bulk_insert(world, e1, { A, B }, { 1, 2 })
		CHECK(c == 1)

		-- Remove e1 from monitor (should clear last_old_archetype)
		world:remove(e1, A)

		-- Second entity: ROOT_ARCHETYPE -> AB (should trigger even though old archetype matches)
		jecs.bulk_insert(world, e2, { A, B }, { 3, 4 })
		CHECK(c == 2)

		-- Re-add e1: ROOT_ARCHETYPE -> AB again (should trigger)
		world:add(e1, A)
		CHECK(c == 3)
	end

	do CASE "mixed bulk_insert and regular add with same old archetype"
		local A = world:component()
		local B = world:component()
		local C = world:component()

		local monitor = ob.monitor(world:query(A, B, C))
		local c = 0
		monitor.added(function()
			c += 1
		end)

		local e1 = world:entity()
		local e2 = world:entity()

		-- First entity: bulk_insert from ROOT_ARCHETYPE (sets last_old_archetype = ROOT_ARCHETYPE, last_entity = e1)
		jecs.bulk_insert(world, e1, { A, B, C }, { 1, 2, 3 })
		CHECK(c == 1)

		-- Second entity: regular add from ROOT_ARCHETYPE
		-- Adding components one by one - callback should trigger when entity matches query
		world:add(e2, A)
		CHECK(c == 1)  -- Entity doesn't match query yet (needs A, B, C)
		world:add(e2, B)
		CHECK(c == 1)  -- Still doesn't match
		world:add(e2, C)
		CHECK(c == 2)  -- Now matches query, should trigger (different entity, so not skipped)
	end

	do CASE "deleted entity should only exit monitor once"
		local A = world:component()
		local B = world:component()

		local c = 0

		local monitor = ob.monitor(world:query(A, B))

		monitor.added(function()
			print("enter")
		end)
		monitor.removed(function()
			c += 1
		end)

		local e = world:entity()
		world:add(e, A)
		world:add(e, B)
		print("---world:delete---")
		world:delete(e)
		print("-----")
		print(c, "c")
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

	do CASE "should not invoke monitor.added callback multiple times in bulk_insert with pairs"
		local A = world:component()
		local B = world:component()
		local e1 = world:entity()
		local e2 = world:entity()

		local monitor = ob.monitor(world:query(jecs.pair(A, e1), jecs.pair(A, e2)))
		local c = 0
		monitor.added(function()
			c += 1
		end)

		local e = world:entity()
		jecs.bulk_insert(world, e, { jecs.pair(A, e1), jecs.pair(A, e2) }, { true, true })
		CHECK(c == 1)
	end

	do CASE "should not invoke monitor.added callback multiple times in bulk_insert with mixed components and pairs"
		local A = world:component()
		local B = world:component()
		local C = world:component()
		local e1 = world:entity()

		local monitor = ob.monitor(world:query(A, B, jecs.pair(C, e1)))
		local c = 0
		monitor.added(function()
			c += 1
		end)

		local e = world:entity()
		jecs.bulk_insert(world, e, { A, B, jecs.pair(C, e1) }, { 1, 2, true })
		CHECK(c == 1)
	end

	do CASE "monitor with wildcard pair should handle bulk_insert"
		local A = world:component()
		local B = world:component()
		local e1 = world:entity()
		local e2 = world:entity()
		local e3 = world:entity()

		local monitor = ob.monitor(world:query(A, jecs.pair(B, jecs.w)))
		local c = 0
		monitor.added(function()
			c += 1
		end)

		local e = world:entity()
		world:add(e, A)
		CHECK(c == 0)
		world:add(e, jecs.pair(B, e1))
		CHECK(c == 1)
		world:add(e, jecs.pair(B, e2))
		CHECK(c == 1)
		world:add(e, jecs.pair(B, e3))
		CHECK(c == 1)
	end

	do CASE "monitor with multiple pairs should handle separate operations correctly"
		local A = world:component()
		local B = world:component()
		local e1 = world:entity()
		local e2 = world:entity()

		local monitor = ob.monitor(world:query(jecs.pair(A, e1), jecs.pair(A, e2)))
		local c = 0
		monitor.added(function()
			c += 1
		end)
		local r = 0
		monitor.removed(function()
			r += 1
		end)

		local e = world:entity()
		world:add(e, jecs.pair(A, e1))
		CHECK(c == 0)
		world:add(e, jecs.pair(A, e2))
		CHECK(c == 1)
		world:remove(e, jecs.pair(A, e1))
		CHECK(r == 1)
		world:remove(e, jecs.pair(A, e2))
		CHECK(r == 1)
		world:add(e, jecs.pair(A, e1))
		CHECK(c == 1)
		world:add(e, jecs.pair(A, e2))
		CHECK(c == 2)
	end

	if true then return end

	do CASE "monitor with pair should handle remove and re-add correctly"
		local A = world:component()
		local B = world:component()
		local e1 = world:entity()

		local monitor = ob.monitor(world:query(jecs.pair(A, e1)))
		local c = 0
		monitor.added(function()
			c += 1
		end)
		local r = 0
		monitor.removed(function()
			r += 1
		end)

		local e = world:entity()
		world:add(e, jecs.pair(A, e1))
		CHECK(c == 1)
		world:remove(e, jecs.pair(A, e1))
		CHECK(r == 1)
		world:add(e, jecs.pair(A, e1))
		CHECK(c == 2)
		world:remove(e, jecs.pair(A, e1))
		CHECK(r == 2)
	end

	do CASE "monitor with pair and without clause should handle bulk operations"
		local A = world:component()
		local B = world:component()
		local C = world:component()
		local e1 = world:entity()
		local e2 = world:entity()

		local monitor = ob.monitor(world:query(A):without(jecs.pair(B, e1)))
		local c = 0
		monitor.added(function()
			c += 1
		end)
		local r = 0
		monitor.removed(function()
			r += 1
		end)

		local e = world:entity()
		world:add(e, A)
		CHECK(c == 1)
		world:add(e, jecs.pair(B, e2))
		CHECK(c == 1)
		world:add(e, jecs.pair(B, e1))
		CHECK(c == 1)
		CHECK(r == 1)
		world:remove(e, jecs.pair(B, e1))
		CHECK(c == 2)
		CHECK(r == 1)
	end

	do CASE "monitor with wildcard pair in without should handle operations correctly"
		local A = world:component()
		local B = world:component()
		local e1 = world:entity()
		local e2 = world:entity()

		local monitor = ob.monitor(world:query(A):without(jecs.pair(B, jecs.w)))
		local c = 0
		monitor.added(function()
			c += 1
		end)
		local r = 0
		monitor.removed(function()
			r += 1
		end)

		local e = world:entity()
		world:add(e, A)
		CHECK(c == 1)
		world:add(e, jecs.pair(B, e1))
		CHECK(c == 1)
		CHECK(r == 1)
		world:add(e, jecs.pair(B, e2))
		CHECK(c == 1)
		CHECK(r == 1)
		world:remove(e, jecs.pair(B, e1))
		CHECK(c == 1)
		CHECK(r == 1)
		world:remove(e, jecs.pair(B, e2))
		CHECK(c == 2)
		CHECK(r == 1)
	end

	do CASE "monitor with multiple pairs should not skip legitimate transitions"
		local A = world:component()
		local B = world:component()
		local e1 = world:entity()
		local e2 = world:entity()
		local e3 = world:entity()

		local monitor = ob.monitor(world:query(jecs.pair(A, e1), jecs.pair(A, e2)))
		local c = 0
		monitor.added(function()
			c += 1
		end)

		local e = world:entity()
		world:add(e, jecs.pair(A, e1))
		CHECK(c == 1)
		world:remove(e, jecs.pair(A, e1))
		world:add(e, jecs.pair(A, e2))
		CHECK(c == 2)
		world:remove(e, jecs.pair(A, e2))
		world:add(e, jecs.pair(A, e1))
		CHECK(c == 3)
		world:add(e, jecs.pair(A, e2))
		CHECK(c == 4)
	end

	do CASE "monitor with pair should handle set operations correctly"
		local A = world:component()
		local B = world:component()
		local e1 = world:entity()

		local monitor = ob.monitor(world:query(jecs.pair(A, e1)))
		local c = 0
		monitor.added(function()
			c += 1
		end)
		local r = 0
		monitor.removed(function()
			r += 1
		end)

		local e = world:entity()
		world:set(e, jecs.pair(A, e1), true)
		CHECK(c == 1)
		world:set(e, jecs.pair(A, e1), false)
		CHECK(c == 1)
		world:set(e, jecs.pair(A, e1), true)
		CHECK(c == 2)
		world:remove(e, jecs.pair(A, e1))
		CHECK(r == 1)
		world:set(e, jecs.pair(A, e1), true)
		CHECK(c == 3)
	end

	do CASE "monitor with pair query should handle non-matching pairs"
		local A = world:component()
		local B = world:component()
		local e1 = world:entity()
		local e2 = world:entity()

		local monitor = ob.monitor(world:query(jecs.pair(A, e1)))
		local c = 0
		monitor.added(function()
			c += 1
		end)

		local e = world:entity()
		world:add(e, jecs.pair(A, e1))
		CHECK(c == 1)
		world:add(e, jecs.pair(A, e2))
		CHECK(c == 1)
		world:add(e, jecs.pair(B, e1))
		CHECK(c == 1)
	end
end)

return FINISH()
