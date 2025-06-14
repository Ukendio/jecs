local jecs = require("@jecs")
local testkit = require("@testkit")
local test = testkit.test()
local CASE, TEST, FINISH, CHECK = test.CASE, test.TEST, test.FINISH, test.CHECK
local observers_add = require("@addons/observers")

TEST("addons/observers", function()
	local world = observers_add(jecs.world())

	local Test = world:component() :: jecs.Id<number>
	type Q<T...> = () -> (jecs.Entity, T...)
	local query:
		(<A>(jecs.World, jecs.Id<A>) -> Q<A>)
		& (<A, B>(jecs.World, jecs.Id<A>, jecs.Id<B>) -> Q<A, B>)
		& (<A, B, C>(jecs.World, jecs.Id<A>, jecs.Id<B>, jecs.Id<C>) -> Q<A, B, C>)
		= 1 :: never
	for e, a in query(world, Test) do

	end

	do CASE "Should work even if set after the component has been used"
		local A = world:component()

		world:set(world:entity(), A, 2)
		local ran = true
		world:added(A, function()
			ran = false
		end)

		local entity = world:entity()
		world:set(entity, A, 3)

		CHECK(ran)
	end

	do CASE "Should not override hook"
		local A = world:component()

		local count = 1
		local function counter()
			count += 2
		end

		world:set(A, jecs.OnAdd, counter)
		world:added(A, counter)
		world:set(world:entity(), A, false)
		CHECK(count == 3)
		world:set(world:entity(), A, false)

		CHECK(count == 5)
	end

	do CASE "Ensure ordering between signals and observers"
		local A = world:component()
		local B = world:component()

		local count = 1
		local function counter()
			count += 2
		end

		world:observer(world:query(A, B), counter)

		world:added(A, counter)
		world:added(A, counter)

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
			count += 2
		end

		world:observer(world:query(A), counter)

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
			count += 2
		end

		world:monitor(world:query(A), counter)

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
			callcount += 2
		end)
		world:added(A, function(entity)
			callcount += 2
		end)

		local e = world:entity()
		local e2 = world:entity()

		world:add(e2, jecs.pair(A, e))
		world:add(e, jecs.pair(A, e2))
		CHECK(callcount == 5)
	end
end)

return FINISH()
