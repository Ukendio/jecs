--------------------------------------------------------------------------------
-- vide.luau
--------------------------------------------------------------------------------

local version = { major = 0, minor = 3, patch = 1 }

if not game then script = require "test/relative-string" end

local root = require(script.root)
local mount = require(script.mount)
local create = require(script.create)
local apply = require(script.apply)
local source = require(script.source)
local effect = require(script.effect)
local derive = require(script.derive)
local cleanup = require(script.cleanup)
local untrack = require(script.untrack)
local read = require(script.read)
local batch = require(script.batch)
local context = require(script.context)
local switch = require(script.switch)
local show = require(script.show)
local indexes, values = require(script.maps)()
local spring, update_springs = require(script.spring)()
local action = require(script.action)()
local changed = require(script.changed)
local throw = require(script.throw)
local flags = require(script.flags)

export type Source<T> = source.Source<T>
export type source<T> = Source<T>
export type Context<T> = context.Context<T>
export type context<T> = Context<T>

local function step(dt: number)
    if game then
        debug.profilebegin("VIDE STEP")
        debug.profilebegin("VIDE SPRING")
    end

    update_springs(dt)

    if game then
        debug.profileend()
        debug.profileend()
    end
end

local stepped = game and game:GetService("RunService").Heartbeat:Connect(function(dt: number)
    task.defer(step, dt)
end)

local vide = {
    version = version,

    -- core
    root = root,
    mount = mount,
    create = create,
    source = source,
    effect = effect,
    derive = derive,
    switch = switch,
    show = show,
    indexes = indexes,
    values = values,

    -- util
    cleanup = cleanup,
    untrack = untrack,
    read = read,
    batch = batch,
    context = context,

    -- animations
    spring = spring,

    -- actions
    action = action,
    changed = changed,

    -- flags
    strict = (nil :: any) :: boolean,

    -- temporary
    apply = function(instance: Instance)
        return function(props: { [any]: any })
            apply(instance, props)
            return instance
        end
    end,

    -- runtime
    step = function(dt: number)
        if stepped then
            stepped:Disconnect()
            stepped = nil
        end
        step(dt)
    end
}

setmetatable(vide :: any, {
    __index = function(_, index: unknown): ()
        if index == "strict" then
            return flags.strict
        else
            throw(`{tostring(index)} is not a valid member of vide`)
        end
    end,

    __newindex = function(_, index: unknown, value: unknown)
        if index == "strict" then
            flags.strict = value :: boolean
        else
            throw(`{tostring(index)} is not a valid member of vide`)
        end
    end
})

return vide
