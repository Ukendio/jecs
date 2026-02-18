local scheduler = require(script.Parent.Parent.server.scheduler)
type Array<T> = { T }

export type System = (any, number) -> ...(any, number) -> ()

type GroupInfo = { i: number?, o: number? }

type SystemGroup = {
    interval: number,
    offset: number,
    dt: number,
    [number]: {
        id: number,
        name: string,
        type: number,
        fn: (...any) -> ...any
    }
}

local function loop_create(name: string, data: any, ...: ModuleScript | () -> () | GroupInfo)
    local jabby_scheduler = scheduler.create(name)
    
    local groups = {} :: Array<SystemGroup>

    local current_group: SystemGroup?

    local function process_systems(array: Array<any>)
        for i, v in array do
            if type(v) == "table" then
                if v.i then
                    if current_group then
                        table.insert(groups, current_group)
                    end

                    current_group = {
                        interval = v.i or 1,
                        offset = v.o or 0,
                        dt = 0
                    }
                else
                    process_systems(v)
                end
            elseif type(v) == "function" then 
                assert(current_group)

                table.insert(current_group, {
                    id = jabby_scheduler:register_system(),
                    name = "UNNAMED",
                    type = 0,
                    fn = v
                })
            else
                assert(current_group)

                local fn = (require :: any)(v) :: System
                local fn2 = fn(data, 0)

                table.insert(current_group, {
                    id = jabby_scheduler:register_system({name = `{v.Name}`}),
                    name = v.Name,
                    type = fn2 and 1 or 0,
                    fn = fn2 or fn
                })
            end
        end
    end

    process_systems { ... }

    assert(current_group)
    table.insert(groups, current_group)
    current_group = nil

    local frame_count = 0

    return function(dt)
        frame_count += 1

        debug.profilebegin("ECS LOOP")

        for _, group in groups do
            group.dt += dt

            if frame_count % group.interval == group.offset then
                for _, system in ipairs(group) do
                    debug.setmemorycategory(system.name)
                    debug.profilebegin(system.name)

                    if system.type == 0 then
                        jabby_scheduler:run(system.id, system.fn, data, group.dt)
                    else
                        jabby_scheduler:run(system.id, system.fn, group.dt)
                    end

                    debug.profileend()
                end

                group.dt = 0
            end
        end

        debug.resetmemorycategory()
        debug.profileend()
    end, jabby_scheduler
end

return loop_create