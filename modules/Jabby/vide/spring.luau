if not game then script = require "test/relative-string" end
local Vector3 = game and Vector3 or require "test/mock".Vector3 :: never

--[[

Supported datatypes:
- number
- CFrame
- Color3
- UDim
- UDim2
- Vector2
- Vector3
- Rect

Unsupported datatypes:
- bool
- Vector2int16
- Vector3int16
- EnumItem

]]

local throw = require(script.Parent.throw)
local graph = require(script.Parent.graph)
type Node<T> = graph.Node<T>
type SourceNode<T> = graph.SourceNode<T>
local create_node = graph.create_node
local create_source_node = graph.create_source_node
local assert_stable_scope = graph.assert_stable_scope
local evaluate_node = graph.evaluate_node
local update_descendants = graph.update_descendants
local push_child_to_scope = graph.push_child_to_scope

local UPDATE_RATE = 120
local TOLERANCE = 0.0001

type Vec3 = Vector3

local function Vec3(x: number?, y: number?, z: number?)
    return Vector3.new(x, y, z)
end

local ZERO = Vec3(0, 0, 0)

type Animatable = number | CFrame | Color3 | UDim | UDim2 | Vector2 | Vector3

type SpringData<T> = {
    k: number, -- spring constant
    c: number, -- damping coeff

    -- dimensions 1-3
    x0_123: Vec3,
    x1_123: Vec3,
    v_123: Vec3,

    -- dimensions 4-6
    x0_456: Vec3,
    x1_456: Vec3,
    v_456: Vec3,

    source_value: T -- current value of spring input source
}

type TypeToVec6<T> = (T) -> (Vec3, Vec3)
type Vec6ToType<T> = (Vec3, Vec3) -> T

local type_to_vec6 = {
    number = function(v)
        return Vec3(v, 0, 0), ZERO
    end :: TypeToVec6<number>,

    CFrame = function(v)
        return v.Position, Vec3(v:ToEulerAnglesXYZ())
    end :: TypeToVec6<CFrame>,

    Color3 = function(v)
        -- todo: hsv, oklab?
        return Vec3(v.R, v.G, v.B), ZERO
    end :: TypeToVec6<Color3>,

    UDim = function(v)
        return Vec3(v.Scale, v.Offset, 0), ZERO
    end :: TypeToVec6<UDim>,
    
    UDim2 = function(v)
        return Vec3(v.X.Scale, v.X.Offset, v.Y.Scale), Vec3(v.Y.Offset, 0, 0)
    end :: TypeToVec6<UDim2>,

    Vector2 = function(v)
        return Vec3(v.X, v.Y, 0), ZERO
    end :: TypeToVec6<Vector2>,

    Vector3 = function(v)
        return v, ZERO
    end :: TypeToVec6<Vector3>,

    Rect = function(v)
        return Vec3(v.Min.X, v.Min.Y, v.Max.X), Vec3(v.Max.Y, 0, 0)
    end :: TypeToVec6<Rect>
}

local vec6_to_type = {
    number = function(a, b)
        return a.X
    end :: Vec6ToType<number>,

    CFrame = function(a, b)
        return CFrame.new(a) * CFrame.fromEulerAnglesXYZ(b.X, b.Y, b.Z)
    end :: Vec6ToType<CFrame>,

    Color3 = function(v)
        return Color3.new(math.clamp(v.X, 0, 1), math.clamp(v.Y, 0, 1), math.clamp(v.Z, 0, 1))
    end :: Vec6ToType<Color3>,

    UDim = function(v)
        return UDim.new(v.X, math.round(v.Y))
    end :: Vec6ToType<UDim>,
    
    UDim2 = function(a, b)
        return UDim2.new(a.X, math.round(a.Y), a.Z, math.round(b.X))
    end :: Vec6ToType<UDim2>,

    Vector2 = function(v)
        return Vector2.new(v.X, v.Y)
    end :: Vec6ToType<Vector2>,

    Vector3 = function(v)
        return v
    end :: Vec6ToType<Vector3>,

    Rect = function(a, b)
        return Rect.new(a.X, a.Y, a.Z, b.X)
    end :: Vec6ToType<Rect>
}

local invalid_type = {
    __index = function(_, t: string)
        throw(`cannot spring type {t}`)
    end
}

setmetatable(type_to_vec6, invalid_type)
setmetatable(vec6_to_type, invalid_type)

-- maps spring data to its corresponding output node
-- lifetime of spring data is tied to output node
local springs: { [SpringData<any>]: SourceNode<any> } = {}
setmetatable(springs, { __mode = "v" })

local function spring<T>(source: () -> T, period: number?, damping_ratio: number?): () -> T
    local owner = assert_stable_scope()

    -- https://en.wikipedia.org/wiki/Damping

    local w_n = 2*math.pi / (period or 1)
    local z = damping_ratio or 1

    local k = w_n^2
    local c_c = 2*w_n
    local c = z * c_c

    -- todo: is there a solution other than reducing step size?
    -- todo: this does not catch all solver exploding cases
    if c > UPDATE_RATE*2 then -- solver will explode if this is true
        throw("spring damping too high, consider reducing damping or increasing period")
    end

    local data: SpringData<T> = {
        k = k,
        c = c,

        x0_123 = ZERO,
        x1_123 = ZERO,
        v_123 = ZERO,

        x0_456 = ZERO,
        x1_456 = ZERO,
        v_456 = ZERO,

        source_value = false :: any,
    }
    
    local output = create_source_node(false :: any)

    local function updater_effect()
        local value = source()
        data.x1_123, data.x1_456 = type_to_vec6[typeof(value)](value)
        data.source_value = value
        springs[data] = output -- todo: investigate why insertion is not O(1) at ~20k springs
        return value
    end

    local updater = create_node(owner, updater_effect, false :: any)

    evaluate_node(updater)

    -- set initial position to goal
    data.x0_123, data.x0_456 = data.x1_123, data.x1_456

    -- set output to goal
    output.cache = data.source_value

    return function(...)
        if select("#", ...) == 0 then -- no args were given
            push_child_to_scope(output)
            return output.cache
        end

        -- set current position to value
        local v = ... :: T
        data.x0_123, data.x0_456 = type_to_vec6[typeof(v)](v)

        -- reset velocity
        data.v_123 = ZERO
        data.v_456 = ZERO

        -- schedule spring
        springs[data] = output

        -- set output to value
        output.cache = v

        return v
    end
end

local function step_springs(dt: number)
    for data in next, springs do
        local k, c,
        x0_123, x1_123, u_123,
        x0_456, x1_456, u_456 =
            data.k, data.c,
            data.x0_123, data.x1_123, data.v_123,
            data.x0_456, data.x1_456, data.v_456

        -- calculate displacement from target
        local dx_123 = x0_123 - x1_123
        local dx_456 = x0_456 - x1_456

        -- calculate spring force
        local fs_123 = dx_123*-k
        local fs_456 = dx_456*-k

        -- calculate friction force
        local ff_123 = u_123*-c
        local ff_456 = u_456*-c

        -- calculate acceleration step
        local dv_123 = (fs_123 + ff_123)*dt
        local dv_456 = (fs_456 + ff_456)*dt

        -- apply acceleration step
        local v_123 = u_123 + dv_123
        local v_456 = u_456 + dv_456

        -- calculate new position
        local x_123 = x0_123 + v_123*dt
        local x_456 = x0_456 + v_456*dt

        data.x0_123, data.x0_456 = x_123, x_456
        data.v_123, data.v_456 = v_123, v_456
    end
end

local remove_queue = {}

local function update_spring_sources()
    for data, output in next, springs do
        local x0_123, x1_123, v_123,
        x0_456, x1_456, v_456 =
            data.x0_123, data.x1_123, data.v_123,
            data.x0_456, data.x1_456, data.v_456
    
        local dx_123, dx_456 =
            x0_123 - x1_123,
            x0_456 - x1_456

        -- todo: can this false positive?
        if (v_123 + v_456 + dx_123 + dx_456).Magnitude < TOLERANCE then
            -- close enough to target, unshedule spring and set value to target
            table.insert(remove_queue, data)
            output.cache = data.source_value
        else
            output.cache = vec6_to_type[typeof(data.source_value)](x0_123, x0_456)
        end

        update_descendants(output)
    end

    for _, data in next, remove_queue do
        springs[data] = nil
    end

    table.clear(remove_queue)
end

return function()
    local time_elapsed = 0

    return spring, function(dt: number)
        time_elapsed += dt

        while time_elapsed > 1 / UPDATE_RATE do
            time_elapsed -= 1 / UPDATE_RATE
            step_springs(1 / UPDATE_RATE)
        end

        update_spring_sources()
    end
end
