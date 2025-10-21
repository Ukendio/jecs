
--!optimize 2
--!native

local testkit = require("@testkit")
local BENCH, START = testkit.benchmark()
local function TITLE(title: string)
	print()
	print(testkit.color.white(title))
end

local jecs = require("@jecs")
local mirror = require("@mirror")

do
	TITLE(testkit.color.white_underline("Jecs query"))
	local world = jecs.world() :: jecs.World

	local A = world:component()

	for i = 1, 100_000 do
		local e = world:entity()
		world:set(e, A, true)
	end

	local archetypes = world:query(A):archetypes()

	BENCH("", function()
		for _, archetype in archetypes do
			local column = archetype.columns[1]
			for row, entity in archetype.entities do
				local data = column[row]
			end
		end
	end)

end
