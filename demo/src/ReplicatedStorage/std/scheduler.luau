local function panic(str)
    -- We don't want to interrupt the loop when we error
    task.spawn(error, str)
end

local function Scheduler(...)
    local systems = { ... }
    local systemsNames = {}
    local N = #systems
    local system
    local dt

    for i, module in systems do
        local sys = require(module)
        systems[i] = sys
        local file, line = debug.info(2, "sl")
        systemsNames[sys] = `{file}->::{line}::->{debug.info(sys, "n")}`
    end

    local function run()
        local name = systemsNames[system]

        debug.profilebegin(name)
        debug.setmemorycategory(name)
        system(dt)
        debug.profileend()
    end

    local function loop(sinceLastFrame)
        debug.profilebegin("loop()")

        for i = N, 1, -1 do
            system = systems[i]

            dt = sinceLastFrame

            local didNotYield, why = xpcall(function()
                for _ in run do end
            end, debug.traceback)

            if didNotYield then
				continue
			end

			if string.find(why, "thread is not yieldable") then
				N -= 1
				local name = table.remove(systems, i)
				panic("Not allowed to yield in the systems."
    				.. "\n"
    				.. `System: {name} has been ejected`
				)
			else
			    panic(why)
			end
        end

        debug.profileend()
        debug.resetmemorycategory()
    end

    return loop
end

return Scheduler
