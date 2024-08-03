-- original author @centauri
local bt
do

    local FAILURE = 0
    local SUCCESS = 1
    local RUNNING = 2

    local function SEQUENCE(nodes)
        return function(...)
            for _, node in nodes do
                local status = node(...)
                if status == FAILURE or status == RUNNING then
                    return status
                end
            end
            return SUCCESS
        end
    end
    local function FALLBACK(nodes)
        return function(...)
            for _, node in nodes do
                local status = node(...)
                if status == SUCCESS or status == RUNNING then
                    return status
                end
            end
            return FAILURE
        end
    end
    bt = {
        SEQUENCE = SEQUENCE,
        FALLBACK = FALLBACK,
        RUNNING = RUNNING,
        SUCCESS = SUCCESS,
        FAILURE = FAILURE,
    }
end

local SEQUENCE, FALLBACK = bt.SEQUENCE, bt.FALLBACK
local RUNNING, SUCCESS, FAILURE = bt.FAILURE, bt.SUCCESS, bt.FAILURE

local btree = FALLBACK {
    SEQUENCE {
        function()
            return 1
        end,

        function()
            return 0
        end
    },
    SEQUENCE {
        function()
            print(3)
            local start = os.clock()
            local now = os.clock()
            while os.clock() - now < 4 do
                print("yielding")
                coroutine.yield()
            end
            return 0
        end
    },
    function()
        return 1
    end
}

function wait(seconds)
    local start = os.clock()
    while os.clock() - start < seconds do end
    return os.clock() - start
end

local function panic(str)
    -- We don't want to interrupt the loop when we error
    coroutine.resume(coroutine.create(function() error(str) end))
end

local jecs = require("@jecs")
local world = jecs.World.new()

local function Scheduler(world, ...)
    local systems = { ... }
    local systemsNames = {}
    local N = #systems
    local system
    local dt

    for i, module in systems do
        local sys = if typeof(module) == "function" then module else require(module)
        systems[i] = sys
        local file, line = debug.info(2, "sl")
        systemsNames[sys] = `{file}->::{line}::->{debug.info(sys, "n")}`
    end

    local function run()
        local name = systemsNames[system]

        --debug.profilebegin(name)
        --debug.setmemorycategory(name)
        system(world, dt)
        --debug.profileend()
    end

    local function loop(sinceLastFrame)
        --debug.profilebegin("loop()")
        local start = os.clock()
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

        --debug.profileend()
        --debug.resetmemorycategory()
        return os.clock() - start
    end

    return loop
end

local co = coroutine.create(btree)
local function ai(world, dt)
    coroutine.resume(co)
end

local loop = Scheduler(world, ai)

while wait(0.2) do
    print("frame time: ", loop(0.2))
end
