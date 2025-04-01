--------------------------------------------------------------------------------
-- jecs.luau
-- v0.9.0
--------------------------------------------------------------------------------

local ID_SIZE = 4
local MAX_ENTITIES = 0x0000_FFFF

--------------------------------------------------------------------------------
-- types
--------------------------------------------------------------------------------

export type entity = number

type Array<T> = { [number]: T }
type Map<T, U> = { [T]: U }
type Listener<T> = (id: entity, value: T) -> ()
type CType = unknown

export type Signal<T...> = {
    connect: (self: Signal<T...>, listener: (T...) -> ()) -> Connection,
}

export type Connection = {
    disconnect: (self: Connection) -> (),
    reconnect: (self: Connection) -> ()
}

type Pool<T> = {
    -- sparse
    map_max: number, -- largest key that can fit
    map: buffer, -- maps keys to internal indexes

    -- dense
    capacity: number, -- allocated amount
    size: number, -- entities in pool
    entities: buffer, -- all entities (0-indexed)
    values: Array<T>, -- all values (1-indexed)

    on_add: Array<Listener<T>> | false,
    on_change: Array<Listener<T>> | false,
    on_remove: Array<Listener<nil>> | false,
    on_clear: Array<() -> ()> | false,
    after_clear: Array<() -> ()> | false,

    group: GroupData<T> | false,

    reserve: (self: Pool<T>, size: number) -> ()
}

type EntityList = {
    data: buffer,
    capacity: number,
    free: number,
}

type GroupData<T = unknown> = {
    size: number, -- entities in group
    added: boolean, -- flag to detect iter invalidation
    connections: Array<Connection>, -- listeners to add and remove from group
    [number]: Pool<T> -- all pools in group
}

export type Handle = typeof(setmetatable(
    {} :: { world: Registry, entity: entity },
    {} :: HandleMT
))

type HandleMT = {
    __index: HandleMT,
    destroy: (self: Handle) -> (),
    has_none: (self: Handle) -> boolean,
    add: <T...>(self: Handle, T...) -> (),
    set: <T>(self: Handle, ctype: T, value: T) -> Handle,
    insert: <T>(self: Handle, ctype: Array<T>, value: T) -> Handle,
    patch: <T>(self: Handle, ctype: T, fn: ((T) -> T)?) -> T,
    has: <T...>(self: Handle, T...) -> boolean,
    get: <T...>(self: Handle, T...) -> T...,
    try_get: <T>(self: Handle, T) -> T?,
    remove: <T...>(self: Handle, T...) -> (),
}

export type View<T...> = typeof(setmetatable({} :: {
    withou: <U...>(self: View<T...>, U...) -> View<T...>,
    patch: (self: View<T...>, fn: (T...) -> T...) -> (),
    iter: (self: View<T...>) -> () -> (entity, T...)
}, {} :: {
    __len: (self: View<T...>) -> number ,
    __iter: (self: View<T...>) -> () -> (entity, T...)
}))

export type Observer<T...> = typeof(setmetatable({} :: {
    withou: <U...>(self: Observer<T...>, U...) -> Observer<T...>,
    disconnect: (self: Observer<T...>) -> Observer<T...>,
    reconnect: (self: Observer<T...>) -> Observer<T...>,
    clear: (self: Observer<T...>) -> Observer<T...>,
    iter: (self: Observer<T...>) -> () -> (entity, T...)
}, {} :: {
    __len: (self: Observer<T...>) -> number,
    __iter: (self: Observer<T...>) -> () -> (entity, T...)
}))

export type Group<T...> = typeof(setmetatable({} :: {
    iter: (self: Group<T...>) -> () -> (entity, T...)
}, {} :: {
    __len: (self: Group<T...>) -> number,
    __iter: (self: Group<T...>) -> () -> (entity, T...)
}))

export type Registry = {
    create: ((self: Registry, id: entity) -> entity) & ((self: Registry) -> entity),
    release: (self: Registry, id: entity) -> (),
    destroy: (self: Registry, id: entity) -> (),
    contains: (self: Registry, id: entity) -> boolean,

    has_none: (self: Registry, id: entity) -> boolean,
    add: <T...>(self: Registry, id: entity, T...) -> (),
    set: <T>(self: Registry, id: entity, ctype: T, value: T) -> (),
    insert: <T>(self: Registry, id: entity, ctype: Array<T>, value: T) -> (),
    patch: <T>(self: Registry, id: entity, ctype: T, fn: ((T) -> T)?) -> T,
    has: <T...>(self: Registry, id: entity, T...) -> boolean,
    get: <T...>(self: Registry, id: entity, T...) -> T...,
    try_get: <T>(self: Registry, id: entity, T) -> T?,
    remove: <T...>(self: Registry, id: entity, T...) -> (),
    find: <T>(self: Registry, ctype: T, value: T) -> entity?,
    copy: <T>(self: Registry, a: T, b: T) -> (),

    query: <T...>(self: Registry, T...) -> View<T...>,
    track: <T...>(self: Registry, T...) -> Observer<T...>,
    group: <T...>(self: Registry, T...) -> Group<T...>,

    clear: <T...>(self: Registry, T...) -> (),
    storage: (<T>(self: Registry, ctype: T) -> Pool<T>) & (<T>(self: Registry) -> () -> (unknown, Pool<unknown>)),

    on_add: <T>(self: Registry, ctype: T) -> Signal<entity, T>,
    on_change: <T>(self: Registry, ctype: T) -> Signal<entity, T>,
    on_remove: <T>(self: Registry, ctype: T) -> Signal<entity, nil>,
    on_clear: <T>(self: Registry, ctype: T) -> Signal<>,
    after_clear: <T>(self: Registry, ctype: T) -> Signal<>,

    handle: ((self: Registry, id: entity) -> Handle) & ((self: Registry) -> Handle),
    context: (self: Registry) -> Handle
}

export type Queue<T...> = typeof(setmetatable({} :: {
    add: (self: Queue<T...>, T...) -> (),
    clear: (self: Queue<T...>) -> (),
    iter: (self: Queue<T...>) -> () -> (T...)
}, {} :: {
    __len: (self: Queue<T...>) -> number,
    __iter: (self: Queue<T...>) -> () -> (T...)
}))

local NIL = nil :: any

-- error but stack trace always starts at first callsite outside of this file
local function throw(msg: string)
    local s = 1
    repeat s += 1 until debug.info(s, "s") ~= debug.info(1, "s") 
    error(msg, s)
end

local ASSERT = function<T>(v: T, msg: string): T
    if v then return v end
    return throw(msg)
end :: typeof(assert)

--------------------------------------------------------------------------------
-- entity id
--------------------------------------------------------------------------------

local RESERVED_BITS = 0

local ID_SIZE_BITS = ID_SIZE * 8
local ID_MAX = 2^(ID_SIZE_BITS - RESERVED_BITS) - 1

local ID_MASK_RES = 0xFFFF_FFFF - ID_MAX
local ID_MASK_KEY = MAX_ENTITIES
local ID_MASK_VER = ID_MAX - ID_MASK_KEY
local ID_MASK_VER_RES = ID_MASK_VER + ID_MASK_RES

local ID_LSHIFT = ID_MASK_KEY + 1
local ID_RSHIFT = 1/ID_LSHIFT

local ID_NULL_KEY = ID_MASK_KEY
local ID_CTX_KEY = 0

local ID_NULL_VER = 0
local ID_MIN_VER = 1 * ID_LSHIFT

local ID_MAX_VALID_KEY = ID_MASK_KEY - 1

assert(ID_SIZE <= 4 and ID_SIZE >= 1)
assert(MAX_ENTITIES <= ID_MAX/2 and MAX_ENTITIES > 0)
assert(bit32.band(MAX_ENTITIES + 1, MAX_ENTITIES) == 0)

local function ID_CREATE(key: number, ver: number): number
    return ver + key
end

local function ID_KEY(id: number): number
    return bit32.band(id, ID_MASK_KEY)
end

local function ID_VER(id: number): number
    return bit32.band(id, ID_MASK_VER)
end

local function ID_REPLACE(id: number, new_key: number): number
    return ID_VER(id) + new_key
end

local function ID_VERSION_NOT_EQUAL(id1: number, id2: number)
    return ID_VER(id1) ~= ID_VER(id2)
end

local function ID_ASSERT_VERSION_EQUAL(id1: number, id2: number)
    if ID_VERSION_NOT_EQUAL(id1, id2) then
        throw("invalid entity")
    end
end

local ID_NULL = ID_CREATE(ID_NULL_KEY, ID_NULL_VER)
local ID_CTX = ID_CREATE(ID_CTX_KEY, ID_MIN_VER)

--------------------------------------------------------------------------------
-- component type
--------------------------------------------------------------------------------

-- a ctor set to `true` indicates component is a tag
local ctype_ctors: Map<CType, (boolean | () -> unknown)> = {}
local ctype_names: Map<CType, string?> = {}
local ctype_n = 0

local function ctype_create<T>(ctor: boolean | () -> unknown): CType
    ctype_n += 1
    ctype_ctors[ctype_n] = ctor
    return ctype_n
end

local function ctype_is_tag(ctype: CType): boolean
    return ctype_ctors[ctype] == true
end

local function ctype_set_name(ctype: CType, name: unknown)
    ctype_names[ctype] = tostring(name)
end

--[[NO INLINE]] local ctype_debug: (ctype: CType?, idx: number?) -> string = (function()
    return function(ctype: CType?, idx: number?)
        local name = ctype_names[ctype]
        return
            if name then `component "{name}"`
            elseif idx then `component (arg #{idx})`
            else "component (unknown)"
    end
end)()

local function CTYPE_VALID(v: unknown): boolean
    return type(v) == "number" and math.floor(v) == v and v > 0 and v <= ctype_n  
end

local function ASSERT_CTYPE_VALID(ctype: unknown, idx: number?)
    if not CTYPE_VALID(ctype) then
        throw(`invalid component {idx and `arg #{idx}` or ""}`)
    end
end

local ctype_entity = ctype_create(false)
ctype_set_name(ctype_entity, "entity")

--------------------------------------------------------------------------------
-- pool
--------------------------------------------------------------------------------

local function next_pow_of_2(x: number)
    assert(x > 0 and x <= 2^32)
    x -= 1
    x = bit32.bor(x, bit32.rshift(x, 1))
    x = bit32.bor(x, bit32.rshift(x, 2))
    x = bit32.bor(x, bit32.rshift(x, 4))
    x = bit32.bor(x, bit32.rshift(x, 8))
    x = bit32.bor(x, bit32.rshift(x, 16))
    return x + 1
end

local function fire<T>(listeners: Array<Listener<T>>, id: entity, value: T)
    for i = #listeners, 1, -1 do
        listeners[i](id, value)         
    end 
end

local function BUFFER_CREATE(size: number): buffer
    return buffer.create(size * ID_SIZE)
end

local function BUFFER_GET(b: buffer, i: number): number
    return buffer.readu32(b, i * ID_SIZE)
end

local function BUFFER_SET(b: buffer, i: number, id: entity)
    buffer.writeu32(b, i * ID_SIZE, id)
end

local function BUFFER_FILL(b: buffer, first: number, last: number, v: number)
    assert(buffer.len(b) >= last * ID_SIZE)
    for i = first * ID_SIZE, last * ID_SIZE, ID_SIZE do
        buffer.writeu32(b, i, v)
    end
end

local function BUFFER_RESIZE(b: buffer, size: number): buffer
    local b_new = buffer.create(size * ID_SIZE)
    local n_old = buffer.len(b)
    
    buffer.copy(b_new, 0, b)

    for i = n_old, size * ID_SIZE - 1, ID_SIZE do
        buffer.writeu32(b_new, i, ID_NULL)
    end

    return b_new
end

-- local function BUFFER_CLONE(b: buffer): buffer
--     local b_new = buffer.create(buffer.len(b))
--     buffer.copy(b_new, 0, b)
--     return b_new
-- end

-- wrappers to treat arrays as 0-indexed
local function ARRAY_SET<T>(t: Array<T>, i: number, v: T)
    t[i + 1] = v
end

local function ARRAY_GET<T>(t: Array<T>, i: number): T
    return t[i + 1]
end

local function ARRAY_SWAP<T>(t: Array<T>, a: number, b: number)
    a += 1
    b += 1
    t[a], t[b] = t[b], t[a]
end

local function ARRAY_SWAP_REMOVE<T>(t: Array<T>, remove: number, swap: number)
    swap += 1
    t[remove + 1] = t[swap]
    t[swap] = nil
end

local function POOL_HAS<T>(pool: Pool<T>, key: number): boolean
    return pool.map_max >= key and BUFFER_GET(pool.map, key) ~= ID_NULL
end

local function POOL_NOT_HAS<T>(pool: Pool<T>, key: number): boolean
    return pool.map_max < key or BUFFER_GET(pool.map, key) == ID_NULL
end

local function POOL_FIND(pool: Pool<any>, key: number): number
    if key > pool.map_max then return ID_NULL end
    return BUFFER_GET(pool.map, key)
end

local function pool_resize_entities<T>(self: Pool<T>, size: number)
    if self.capacity >= size then return end
    local new_capacity = math.ceil(size * 1.5)
    self.entities = BUFFER_RESIZE(self.entities, new_capacity)
    self.capacity = new_capacity
end

local function pool_resize_map<T>(self: Pool<T>, size: number)
    if self.map_max + 1 >= size then return end
    local new_map_capacity = math.ceil(size * 1.5)
    self.map = BUFFER_RESIZE(self.map, new_map_capacity)
    self.map_max = new_map_capacity - 1
end

local function POOL_RESIZE_MAP_IF_NEEDED<T>(self: Pool<T>, key: number)
    if self.map_max < key then
        pool_resize_map(self, key + 1)
    end
end

local function POOL_SWAP<T>(
    self: Pool<T>,
    idx: number,
    idx_swap: number
)
    local map = self.map
    local entities = self.entities
    local values = self.values

    local id = BUFFER_GET(entities, idx)
    local id_swap = BUFFER_GET(entities, idx_swap)

    BUFFER_SET(entities, idx_swap, id)
    BUFFER_SET(entities, idx, id_swap)

    BUFFER_SET(map, ID_KEY(id), ID_REPLACE(id, idx_swap))
    BUFFER_SET(map, ID_KEY(id_swap), ID_REPLACE(id_swap, idx))
    
    ARRAY_SWAP(values, idx_swap, idx)
end

local function GROUP_ADD<T>(group: GroupData<T>, key: number)
    group.added = true -- used to test for invalidation
    local n = group.size
    group.size = n + 1
    for _, pool in ipairs(group) do
        POOL_SWAP(pool, ID_KEY(BUFFER_GET(pool.map, key)), n)
    end
end

local function GROUP_CAN_ADD<T>(group: GroupData<T>, key: number): boolean
    for _, pool in ipairs(group) do
        if POOL_NOT_HAS(pool, key) then
            return false
        end
    end
    return true
end

local function GROUP_REMOVE<T>(group: GroupData<T>, idx: number)
    local n = group.size - 1
    group.size = n
    for _, pool in ipairs(group) do        
        POOL_SWAP(pool, idx, n)
    end
end

local function POOL_TRY_GROUP<T>(pool: Pool<T>, id: number)
    local group = pool.group :: GroupData<T>
    local key = ID_KEY(id)
    if GROUP_CAN_ADD(group, key) then
        GROUP_ADD(group, key)  
    end
end

local function POOL_TRY_UNGROUP<T>(pool: Pool<T>, id: entity)
    local group = pool.group :: GroupData<T>
    local idx = ID_KEY(BUFFER_GET(pool.map, ID_KEY(id)))
    if idx < group.size then
        GROUP_REMOVE(group, idx)
    end
end

local function POOL_RESIZE_ENTITIES_IF_NEEDED<T>(self: Pool<T>, size: number)
    if size >= self.capacity then
        pool_resize_entities(self, size + 1)
    end
end

-- separated to encourage compiler to inline
local function _POOL_ADD(self, i, id, v)
    BUFFER_SET(self.map, ID_KEY(id), ID_REPLACE(id, i))
    BUFFER_SET(self.entities, i, id)
    ARRAY_SET(self.values, i, v)
end
local function POOL_ADD<T>(self: Pool<T>, id: entity, v: T)
    local n = self.size
    POOL_RESIZE_ENTITIES_IF_NEEDED(self, n)
    self.size = n + 1
    _POOL_ADD(self, n, id, v)
    if self.on_add then fire(self.on_add, id, v) end
end

local function _POOL_ADD_ID(self, i, id)
    BUFFER_SET(self.map, ID_KEY(id), ID_REPLACE(id, i))
    BUFFER_SET(self.entities, i, id)
end
local function POOL_ADD_ID<T>(self: Pool<T>, id: entity)
    local n = self.size
    POOL_RESIZE_ENTITIES_IF_NEEDED(self, n)
    self.size = n + 1
    _POOL_ADD_ID(self, n, id)
    if self.on_add then fire(self.on_add, id, NIL) end
end

local function POOL_REMOVE<T>(self: Pool<T>, key, id)
    local map = self.map

    if self.on_remove then fire(self.on_remove, id) end

    local idx_ver = BUFFER_GET(map, key)
    local idx = ID_KEY(idx_ver)

    if ID_VERSION_NOT_EQUAL(idx_ver, id) then return end

    local n = self.size - 1
    self.size = n
    local entities = self.entities
    local values = self.values

    local id_last = BUFFER_GET(entities, n)

    BUFFER_SET(map, ID_KEY(id_last), ID_REPLACE(id_last, idx))
    BUFFER_SET(map, key, ID_NULL)

    BUFFER_SET(entities, idx, id_last)
    --BUFFER_SET(entities, n, ID_NULL)

    ARRAY_SWAP_REMOVE(values, idx, n)
end
local function POOL_TRY_REMOVE<T>(self: Pool<T>, id: entity)
    local key = ID_KEY(id)
    if POOL_HAS(self, key) then
        POOL_REMOVE(self, key, id)
    end
end

local function POOL_COPY<T>(self: Pool<T>, into: Pool<T>)
    if into.on_add or into.on_change or into.on_remove or into.on_clear then throw("cannot paste into component with signals") end

    POOL_RESIZE_MAP_IF_NEEDED(into, self.map_max)
    POOL_RESIZE_ENTITIES_IF_NEEDED(into, self.capacity)
    
    into.size = self.size
    
    buffer.copy(into.map, 0, self.map, 0)
    buffer.copy(into.entities, 0, self.entities, 0)
    table.move(self.values, 1, math.max(self.size, into.size), 1, into.values)
end

local function pool_clear<T>(self: Pool<T>)
    local entities = self.entities

    local on_clear = self.on_clear :: Array<() -> ()>
    if on_clear then
        for _, listener in on_clear do listener() end
    end

    local on_remove = self.on_remove :: Array<Listener<nil>>
    if on_remove then
        for i = 0, self.size - 1 do
            fire(on_remove, BUFFER_GET(entities, i))
        end
    end

    local after_clear = self.after_clear :: Array<() -> ()>
    if after_clear then
        for _, listener in after_clear do listener() end
    end

    self.size = 0
    BUFFER_FILL(self.map, 0, self.map_max, ID_NULL)
    table.clear(self.values)
end

local function pool_create<T>(size: number?): Pool<T>
    local n = size or 1

    local map = BUFFER_CREATE(n)
    BUFFER_FILL(map, 0, n - 1, ID_NULL)

    return {
        map_max = n - 1,
        capacity = n,
        size = 0,
        map = map,
        entities = BUFFER_CREATE(n),
        values = table.create(n),

        on_add = false,
        on_change = false,
        on_remove = false,
        on_clear = false,
        after_clear = false,
        group = false,

        reserve = function(self: Pool<T>, size: number)
            pool_resize_map(self, size)
            pool_resize_entities(self, size)

            -- todo: why does this cause innacurate buffer alloc readings?
            do -- force array reallocation
                local values = self.values
                local n = next_pow_of_2(size)

                for i = self.size + 1, n do
                    values[i] = true :: any
                end

                for i = n, self.size + 1, -1 do
                    values[i] = nil
                end
            end
        end
    }
end

--------------------------------------------------------------------------------
-- entity_list
--------------------------------------------------------------------------------

local function entity_list_create(): EntityList
    return {
        data = buffer.create(0),
        capacity = 0,
        free = ID_NULL_KEY
    }
end

local function entity_list_get_prev_key(self: EntityList, key: number): number
    local prev = self.free
    local i = 0; repeat i += 1
        local next = ID_KEY(BUFFER_GET(self.data, prev))
        if next == key then break end
        prev = next
    until i == ID_MAX_VALID_KEY
    assert(i < ID_MAX_VALID_KEY, "key not found") -- todo: is this a valid case?
    return prev
end

local function entity_list_resize(self: EntityList, new_capacity: number, partition_start: number, partition_stop: number)
    ASSERT(new_capacity > self.capacity, "new capacity must be greater than current capacity")
    local new_max = new_capacity - 1
    ASSERT(new_max <= ID_MAX_VALID_KEY)

    local old_capacity = self.capacity
    local old_max = old_capacity - 1
    local old_data = self.data

    local new_data = BUFFER_RESIZE(old_data, new_capacity)

    if old_max < partition_stop and new_max >= partition_start then
        local start = old_max < partition_start and partition_start or old_max + 1 -- todo: verify
        local stop = new_max > partition_stop and partition_stop or new_max

        if self.free == ID_NULL_KEY then
            self.free = start
        else
            local tail = entity_list_get_prev_key(self, ID_NULL_KEY)
            BUFFER_SET(new_data, tail, ID_CREATE(start, ID_VER(BUFFER_GET(new_data, tail))))
        end

        for i = start, stop - 1 do
            BUFFER_SET(new_data, i, ID_CREATE(i + 1, ID_MIN_VER))
        end
        BUFFER_SET(new_data, stop, ID_CREATE(ID_NULL_KEY, ID_MIN_VER))
    end
    
    self.data = new_data
    self.capacity = new_capacity
end

local function entity_list_remove(self: EntityList, id: entity, partition_start: number, partition_stop: number)
    local key = ID_KEY(id)
    local ver = ID_VER(id)

    if key >= partition_start and key <= partition_stop then
        BUFFER_SET(self.data, key, ID_CREATE(self.free, ver < ID_MASK_VER and ver + 1 * ID_LSHIFT or ID_MIN_VER))
        self.free = key
    else
        BUFFER_SET(self.data, key, ID_NULL)
    end
end

local function entity_list_clear(self: EntityList, partition_start: number, partition_stop: number)
    for i = self.capacity - 1, 0, -1 do
        local key_ver = BUFFER_GET(self.data, i)
        if ID_KEY(key_ver) == i then -- is in use
            entity_list_remove(self, key_ver, partition_start, partition_stop)
        end
    end
end

local function ENTITY_LIST_ID_IN_USE(self: EntityList, id: entity): boolean
    local key = ID_KEY(id)
    return key < self.capacity and BUFFER_GET(self.data, ID_KEY(id)) == id
end

--------------------------------------------------------------------------------
-- query
--------------------------------------------------------------------------------

local query_create, observer_create, group_create do

type IRegistry = {
    storage: <T>(self: IRegistry, ctype: T) -> Pool<T>,
    on_add: <T>(self: IRegistry, ctype: T) -> Signal<entity, T>,
    on_change: <T>(self: IRegistry, ctype: T) -> Signal<entity, T>,
    on_remove: <T>(self: IRegistry, ctype: T) -> Signal<entity, nil>,
    on_clear: <T>(self: IRegistry, ctype: T) -> Signal<>,
    after_clear: <T>(self: IRegistry, ctype: T) -> Signal<>,
}

local function HAS_ANY(pools: Array<Pool<unknown>>, key: number): boolean
    for _, pool in next, pools do
        if POOL_HAS(pool, key) then return true end
    end
    return false
end

local function get_smallest(pools: Array<Pool<unknown>>): (Pool<unknown>, number)
    local pool: Pool<unknown>?
    local pos = 0

    for i, p in next, pools do
        if pool == nil or p.size < pool.size then
            pool = p
            pos = i
        end
    end

    return assert(pool, "no pools given"), pos
end

local get_smallest_first_tuple = {}
local function get_smallest_first(pools: Array<Pool<unknown>>): (number, ...Pool<unknown>)
    table.clear(get_smallest_first_tuple)
    local s, s_pos = get_smallest(pools)
    for i, p in next, pools do
        if p ~= s then
            table.insert(get_smallest_first_tuple, p)
        end
    end
    return s_pos, s, unpack(get_smallest_first_tuple)
end

local function get_pools(world: IRegistry, ctypes: Array<CType>): Array<Pool<unknown>>
    local pools = table.create(#ctypes)
    for i, ctype in next, ctypes do
        pools[i] = world:storage(ctype)
    end
    return pools
end

local function disconnect_all(connections: Array<Connection>)
    for _, connection in next, connections do
        connection:disconnect()
    end
end

local function clear_invalidation_flag<T>(pool: Pool<T>)
    if pool.group then pool.group.added = false end
end

local function ASSERT_INVALIDATION<T>(pool: Pool<T>): ...any
    if pool.group and pool.group.added then
        throw("group reordered during iteration")
    end
end

local function query_iter_1<A>(a: Pool<A>): () -> (entity, A)
    local n = a.size
    local entities = a.entities
    local values = a.values

    clear_invalidation_flag(a)

    return function()
        local i = n - 1; n = i

        if i < 0 then
            ASSERT_INVALIDATION(a)
            return NIL, NIL
        end

        return BUFFER_GET(entities, i), ARRAY_GET(values, i)
    end
end

local function query_iter_1_excl_1<A>(a: Pool<A>, b: Pool<unknown>): () -> (entity, A)
    local n = a.size
    local entities = a.entities
    local values = a.values

    clear_invalidation_flag(a)

    return function()
        for i = n - 1, 0, -1 do
            local id = BUFFER_GET(entities, i)

            if POOL_FIND(b, ID_KEY(id)) ~= ID_NULL then continue end
            n = i

            return id, ARRAY_GET(values, i)
        end

        ASSERT_INVALIDATION(a)
        return NIL, NIL
    end
end

local function query_iter_2<A, B>(a: Pool<A>, b: Pool<B>): () -> (entity, A, B)
    local na, nb = a.size, b.size

    if na <= nb then
        local n = na
        local entities = a.entities
        local values = a.values

        clear_invalidation_flag(a)

        return function()
            for i = n - 1, 0, -1 do
                local id = BUFFER_GET(entities, i)
                local idx_ver = POOL_FIND(b, ID_KEY(id))
                if idx_ver == ID_NULL then continue end
                n = i
                return id, ARRAY_GET(values, i), ARRAY_GET(b.values, ID_KEY(idx_ver))
            end
    
            ASSERT_INVALIDATION(a)
            return NIL, NIL, NIL
        end
    else
        local n = nb
        local entities = b.entities
        local values = b.values

        clear_invalidation_flag(b)

        return function()
            for i = n - 1, 0, -1 do
                local id = BUFFER_GET(entities, i)
                local idx_ver = POOL_FIND(a, ID_KEY(id))
                if idx_ver == ID_NULL then continue end
                n = i
                return id, ARRAY_GET(a.values, ID_KEY(idx_ver)), ARRAY_GET(values, i)   
            end
    
            ASSERT_INVALIDATION(b)
            return NIL, NIL, NIL
        end
    end
end

local function query_iter_2_excl_1<A, B>(a: Pool<A>, b: Pool<B>, c: Pool<unknown>): () -> (entity, A, B)
    local na, nb = a.size, b.size

    if na <= nb then
        local n = na
        local entities = a.entities
        local values = a.values

        clear_invalidation_flag(a)

        return function()
            for i = n - 1, 0, -1 do
                local id = BUFFER_GET(entities, i)
                local key = ID_KEY(id)
                if POOL_FIND(c, key) ~= ID_NULL then continue end
                local idx_ver = POOL_FIND(b, key)
                if idx_ver == ID_NULL then continue end
                n = i
                return id, ARRAY_GET(values, i), ARRAY_GET(b.values, ID_KEY(idx_ver))
            end
    
            ASSERT_INVALIDATION(a)
            return NIL, NIL, NIL
        end
    else
        local n = nb
        local entities = b.entities
        local values = b.values

        clear_invalidation_flag(b)

        return function()
            for i = n - 1, 0, -1 do
                local id = BUFFER_GET(entities, i)
                local key = ID_KEY(id)
                if POOL_FIND(c, key) ~= ID_NULL then continue end
                local idx_ver = POOL_FIND(a, key)
                if idx_ver == ID_NULL then continue end
                n = i
                return id, ARRAY_GET(a.values, ID_KEY(idx_ver)), ARRAY_GET(values, i)   
            end
    
            ASSERT_INVALIDATION(b)
            return NIL, NIL, NIL
        end
    end
end

local function query_iter_3(includes: Array<Pool<unknown>>): () -> (entity, ...any)
    local s_pos, s, a, b = get_smallest_first(includes)

    local n = s.size
    local entities = s.entities
    local values = s.values

    clear_invalidation_flag(s)

    return function()
        for i = n - 1, 0, -1 do
            local id = BUFFER_GET(entities, i)
            local key = ID_KEY(id)
            
            local a_idx_ver = POOL_FIND(a, key)
            if a_idx_ver == ID_NULL then continue end
            local va = ARRAY_GET(a.values, ID_KEY(a_idx_ver))

            local b_idx_ver = POOL_FIND(b, key)
            if b_idx_ver == ID_NULL then continue end
            local vb = ARRAY_GET(b.values, ID_KEY(b_idx_ver))

            local sv = ARRAY_GET(values, i)

            n = i
            if s_pos == 1 then
                return id, sv, va, vb
            elseif s_pos == 2 then
                return id, va, sv, vb
            else
                return id, va, vb, sv
            end
        end

        ASSERT_INVALIDATION(s)
        return NIL
    end
end

local function query_iter_4(includes: Array<Pool<unknown>>): () -> (entity, ...any)
    local s_pos, s, a, b, c = get_smallest_first(includes)

    local n = s.size
    local entities = s.entities
    local values = s.values

    clear_invalidation_flag(s)

    return function()
        for i = n - 1, 0, -1 do
            local id = BUFFER_GET(entities, i)
            local key = ID_KEY(id)
            
            local a_idx_ver = POOL_FIND(a, key)
            if a_idx_ver == ID_NULL then continue end
            local va = ARRAY_GET(a.values, ID_KEY(a_idx_ver))

            local b_idx_ver = POOL_FIND(b, key)
            if b_idx_ver == ID_NULL then continue end
            local vb = ARRAY_GET(b.values, ID_KEY(b_idx_ver))

            local c_idx_ver = POOL_FIND(c, key)
            if c_idx_ver == ID_NULL then continue end
            local vc = ARRAY_GET(c.values, ID_KEY(c_idx_ver))

            local sv = ARRAY_GET(values, i)

            n = i
            if s_pos == 1 then
                return id, sv, va, vb, vc
            elseif s_pos == 2 then
                return id, va, sv, vb, vc
            elseif s_pos == 3 then
                return id, va, vb, sv, vc
            else
                return id, va, vb, vc, sv
            end
        end

        ASSERT_INVALIDATION(s)
        return NIL
    end
end

local function query_iter_general(
    includes: Array<Pool<unknown>>,
    withouts: Array<Pool<unknown>>?,
    lead: Pool<unknown>?
): () -> (entity, ...any)
    local source = lead or get_smallest(includes)
    local source_pos: number?
    for i, pool in next, includes do
        if pool == source then
            source_pos = i
            break
        end
    end
    assert(source_pos)

    local n = source.size
    local entities = source.entities
    local values = source.values

    local last_pos = #includes
    local tuple = table.create(last_pos)

    clear_invalidation_flag(source)

    return function()
        for i = n - 1, 0, -1 do
            local id = BUFFER_GET(entities, i)
            local key = ID_KEY(id)
            
            if withouts and HAS_ANY(withouts, key) then continue end

            local has_all = true

            for pos = 1, source_pos - 1 do
                local pool = includes[pos]
                local idx_ver = POOL_FIND(pool, key)
                if idx_ver == ID_NULL then has_all = false; break end
                tuple[pos] = ARRAY_GET(pool.values, ID_KEY(idx_ver))
            end

            if has_all == false then continue end
            
            for pos = source_pos + 1, last_pos do
                local pool = includes[pos]
                local idx_ver = POOL_FIND(pool, key)
                if idx_ver == ID_NULL then has_all = false; break end
                tuple[pos] = ARRAY_GET(pool.values, ID_KEY(idx_ver))
            end

            if has_all == false then continue end

            tuple[source_pos] = ARRAY_GET(values, i)
            n = i
            return id, unpack(tuple)
        end

        ASSERT_INVALIDATION(source)
        return NIL
    end
end

local function query_patch_1<A>(a: Pool<A>, fn: (A) -> A)
    local entities = a.entities
    local values = a.values

    local on_change = a.on_change :: Array<Listener<A>>
    if on_change then
        for i, v in values do
            local v_new = fn(v)
            fire(on_change, BUFFER_GET(entities, i - 1), v_new)
            values[i] = v_new
        end
    else
        for i, v in values do
            values[i] = fn(v)
        end
    end
end

local function query_patch_2<A, B>(a: Pool<A>, b: Pool<B>, fn: (A, B) -> (A, B))
    local na, nb = a.size, b.size

    local a_on_change = a.on_change :: Array<Listener<A>>
    local b_on_change = b.on_change :: Array<Listener<B>>

    if na <= nb then
        local n = na
        local entities = a.entities
        local values = a.values

        for i = 0, n - 1 do
            local id = BUFFER_GET(entities, i)
            local idx_ver = POOL_FIND(b, ID_KEY(id))
            if idx_ver == ID_NULL then continue end
            local idx = ID_KEY(idx_ver)

            local va_new, vb_new = fn(ARRAY_GET(values, i), ARRAY_GET(b.values, idx))

            if a_on_change then fire(a_on_change, id, va_new) end
            if b_on_change then fire(b_on_change, id, vb_new) end

            ARRAY_SET(values, i, va_new)
            ARRAY_SET(b.values, idx, vb_new)
        end

    else
        local n = nb
        local entities = b.entities
        local values = b.values

        for i = 0, n - 1 do
            local id = BUFFER_GET(entities, i)
            local idx_ver = POOL_FIND(a, ID_KEY(id))
            if idx_ver == ID_NULL then continue end
            local idx = ID_KEY(idx_ver)

            local va_new, vb_new = fn(ARRAY_GET(a.values, idx), ARRAY_GET(values, i))

            if a_on_change then fire(a_on_change, id, va_new) end
            if b_on_change then fire(b_on_change, id, vb_new) end

            ARRAY_SET(a.values, idx, va_new)
            ARRAY_SET(values, i, vb_new)
        end
    end
end

local function query_patch_general(
    includes: Array<Pool<unknown>>,
    withouts: Array<Pool<unknown>>?,
    fn: (...unknown) -> ...unknown
)
    ASSERT(#includes <= 4, "cannot patch a query with more than 4 component types")
    local source = get_smallest(includes)
    local source_pos: number?
    for i, pool in next, includes do
        if pool == source then
            source_pos = i
            break
        end
    end
    assert(source_pos)

    local n = source.size
    local entities = source.entities
    local values = source.values

    local last_pos = #includes
    local tuple = table.create(last_pos)
    local idxs = table.create(last_pos)

    for i = 0, n - 1 do
        local id = BUFFER_GET(entities, i)
        local key = ID_KEY(id)
        
        if withouts and HAS_ANY(withouts, key) then continue end

        local has_all = true

        for pos = 1, source_pos - 1 do
            local pool = includes[pos]
            local idx_ver = POOL_FIND(pool, key)
            if idx_ver == ID_NULL then has_all = false; break end
            local idx = ID_KEY(idx_ver)
            tuple[pos] = ARRAY_GET(pool.values, idx)
            idxs[pos] = idx
        end

        if has_all == false then continue end
        
        for pos = source_pos + 1, last_pos do
            local pool = includes[pos]
            local idx_ver = POOL_FIND(pool, key)
            if idx_ver == ID_NULL then has_all = false; break end
            local idx = ID_KEY(idx_ver)
            tuple[pos] = ARRAY_GET(pool.values, idx)
            idxs[pos] = idx
        end

        if has_all == false then continue end

        tuple[source_pos] = ARRAY_GET(values, i)
        idxs[source_pos] = i

        tuple[1], tuple[2], tuple[3], tuple[4] =
            fn(tuple[1], tuple[2], tuple[3], tuple[4])

        for pos, pool in includes do
            local on_change = pool.on_change :: Array<Listener<unknown>>
            if on_change then fire(on_change, id, tuple[pos]) end
            ARRAY_SET(pool.values, idxs[pos], tuple[pos])
        end
    end

    return NIL
end

type _View<T...> = typeof(setmetatable({} :: {
    world: IRegistry,
    includes: Array<CType>,
    withouts: Array<CType>?,
    
    withou: <U...>(_View<T...>, U...) -> _View<T...>,
    patch: (_View<T...>, fn: (T...) -> T...) -> (),
    iter: (_View<T...>) -> () -> (entity, T...)
}, {} :: {
    __len: (_View<T...>) -> number,
    __iter: (_View<T...>) -> () -> (entity, T...)
}))

function query_create<T...>(reg: IRegistry, ...: T...): View<T...>
    local includes = {}

    for i = 1, select("#", ...) do
        local ctype = select(i, ...)
        ASSERT_CTYPE_VALID(ctype, i)
        table.insert(includes, ctype)
    end

    local function iter(self: _View<T...>): () -> (entity, T...)
        local includes = get_pools(self.world, self.includes)
        local withouts = self.withouts and get_pools(self.world, self.withouts)

        return if #includes == 1 and not withouts then
                query_iter_1(includes[1])
            elseif #includes == 1 and withouts and #withouts == 1 then
                query_iter_1_excl_1(includes[1], withouts[1])
            elseif #includes == 2 and not withouts then 
                query_iter_2(includes[1], includes[2])
            elseif #includes == 2 and withouts and #withouts == 1 then
                query_iter_2_excl_1(includes[1], includes[2], withouts[1])
            elseif #includes == 3 and not withouts then
                query_iter_3(includes)
            elseif #includes == 4 and not withouts then
                query_iter_4(includes)
            else
                query_iter_general(includes, withouts)   
    end

    local self = {
        world = reg,
        includes = includes,
        withouts = nil,

        withou = function<E...>(self: _View<T...>, ...: E...): _View<T...>
            local includes = self.includes
            local withouts = self.withouts or (function()
                local t = {} 
                self.withouts = t
                return t
            end)()

            for i = 1, select("#", ...) do
                local ctype = select(i, ...)
                ASSERT_CTYPE_VALID(ctype, i)
                ASSERT(not table.find(includes, ctype), `cannot withou {ctype_debug(ctype, i)}, component is a part of the query`)
                if table.find(withouts, ctype) then continue end
                table.insert(withouts, ctype)
            end

            return self
        end,

        patch = function(self: _View<T...>, fn: (T...) -> T...)
            local includes = get_pools(self.world, self.includes)
            local withouts = self.withouts and get_pools(self.world, self.withouts)

            if #includes == 1 and not withouts then
                query_patch_1(includes[1], fn :: any)
            elseif #includes == 2 and not withouts then
                query_patch_2(includes[1], includes[2], fn :: any)
            else
                query_patch_general(includes, withouts, fn :: any)
            end
        end,

        iter = iter,

        __len = function(self: _View<T...>): number
            return get_smallest(get_pools(self.world, self.includes)).size
        end,

        __iter = iter
    }

    setmetatable(self, self)

    return self :: _View<T...>
end

type _Observer<T...> = typeof(setmetatable({} :: {
    world: IRegistry,
    pool: Pool<unknown>,
    includes: Array<CType>,
    withouts: Array<CType>?,
    connections: Array<Connection>?,

    withou: <U...>(_Observer<T...>, U...) -> _Observer<T...>,
    disconnect: (_Observer<T...>) -> _Observer<T...>,
    reconnect: (_Observer<T...>) -> _Observer<T...>,

    clear: (_Observer<T...>) -> _Observer<T...>,
    iter: (_Observer<T...>) -> () -> (entity, T...)
}, {} :: {
    __len: (_Observer<T...>) -> number,
    __iter: (_Observer<T...>) -> () -> (entity, T...)
}))

function observer_create<T...>(reg: IRegistry, ...: T...): Observer<T...>
    local includes = {}

    for i = 1, select("#", ...) do
        local ctype = select(i, ...)
        ASSERT_CTYPE_VALID(ctype, i)
        table.insert(includes, ctype)
    end

    local function iter(self: _Observer<T...>): () -> (entity, T...)
        local pool = self.pool
        local reg = self.world
        local includes = get_pools(reg, self.includes)
        local withouts = self.withouts and get_pools(reg, self.withouts)
    
        local n = pool.size
        local entities = pool.entities
    
        local reg_pool = includes[1]
        local reg_map = reg_pool.map
        local reg_values = reg_pool.values
    
        local tuple = table.create(#includes) :: Array<any>
    
        return if #includes == 1 and not withouts then 
                function()
                    local i = n - 1
                    n = i

                    if i < 0 then
                        self:clear()
                        return NIL
                    end

                    local id = BUFFER_GET(entities, i)

                    return id, ARRAY_GET(
                        reg_values,
                        ID_KEY(BUFFER_GET(reg_map, ID_KEY(id)))
                    ) :: any
                end 
            else
                function()
                    for i = n - 1, 0, -1 do
                        local id = BUFFER_GET(entities, i)
                        local key = ID_KEY(id)
    
                        if withouts and HAS_ANY(withouts, key) then continue end
    
                        local has_all = true
                        for pos, pool in next, includes do
                            local idx_ver = POOL_FIND(pool, key) -- todo: guarantee
                            if idx_ver == ID_NULL then has_all = false; break end
                            tuple[pos] = ARRAY_GET(pool.values, ID_KEY(idx_ver))
                        end

                        if has_all == false then continue end
    
                        n = i
                        return id, unpack(tuple)
                    end

                    self:clear()
                return nil :: any, nil :: any
            end
    end

    local self = {
        world = reg,
        pool = pool_create(), -- treat all initial ids as changed
        includes = includes,
        withouts = nil,
        connections = nil,

        withou = function<E...>(self: _Observer<T...>, ...: E...): _Observer<T...>
            local withouts = self.withouts or (function()
                local t = {} 
                self.withouts = t
                return t
            end)()
        
            for i = 1, select("#", ...) do
                local ctype = select(i, ...)
                ASSERT_CTYPE_VALID(ctype, i)
                ASSERT(not table.find(self.includes, ctype), `cannot withou {ctype_debug(ctype, i)}, component is being tracked`)
                if table.find(withouts, ctype) then continue end
                table.insert(withouts, ctype)
            end
        
            return self
        end,

        disconnect = function(self: _Observer<T...>): _Observer<T...>
            ASSERT(self.pool.size == 0, "attempt to disconnect a non-empty observer")
            if not self.connections then return self end
            disconnect_all(self.connections)
            self.connections = nil
            return self
        end,

        reconnect = function(self: _Observer<T...>): _Observer<T...>
            if self.connections then return self end

            local reg = self.world
            local pool = self.pool
            local includes = self.includes

            local all_connections = {}
            local remove_connections = {}

            for i, ctype in includes do
                local function added_or_changed_listener(id)
                    local key = ID_KEY(id)
                    POOL_RESIZE_MAP_IF_NEEDED(pool, key)
                    local idx_ver = BUFFER_GET(pool.map, key)

                    if idx_ver == ID_NULL then
                        local n = pool.size
                        POOL_RESIZE_ENTITIES_IF_NEEDED(pool, n)
                        pool.size = n + 1
                        BUFFER_SET(pool.map, key, ID_REPLACE(id, n))
                        BUFFER_SET(pool.entities, n, id)
                    end 
                end

                local function removed_listener(id: number)
                    local map = pool.map
                    local entities = pool.entities

                    local key = ID_KEY(id)
                    local idx_ver = POOL_FIND(pool, key)

                    if idx_ver ~= ID_NULL then
                        local n = pool.size - 1
                        pool.size = n
                        local idx = ID_KEY(idx_ver)
                        local id_last = BUFFER_GET(entities, n)
                
                        BUFFER_SET(map, ID_KEY(id_last), ID_REPLACE(id_last, idx))
                        BUFFER_SET(map, key, ID_NULL)
                        
                        BUFFER_SET(entities, idx, id_last)
                        --BUFFER_SET(entities, n, ID_NULL)
                    end
                end
                
                table.insert(all_connections, reg:on_add(ctype):connect(added_or_changed_listener))
                table.insert(all_connections, reg:on_change(ctype):connect(added_or_changed_listener))

                local remove_connection = reg:on_remove(ctype):connect(removed_listener)
                table.insert(all_connections, remove_connection)
                table.insert(remove_connections, remove_connection)

                table.insert(all_connections, reg:on_clear(ctype):connect(function()
                    for _, cn in remove_connections do cn:disconnect() end
                end))

                table.insert(all_connections, reg:after_clear(ctype):connect(function()
                    pool_clear(self.pool)
                    for _, cn in remove_connections do cn:reconnect() end
                end))
            end

            self.connections = all_connections

            return self
        end,

        clear = function(self: _Observer<T...>): _Observer<T...>
            pool_clear(self.pool)
            return self
        end,

        iter = function(self) return iter(self) end,

        __len = function(self: _Observer<T...>): number
            return self.pool.size
        end,

        __iter = function(self) return iter(self) end
    }

    setmetatable(self, self)

    return self:reconnect()  :: _Observer<T...>
end

type _Group<T...> = typeof(setmetatable({} :: {
    data: GroupData,
    pools: Array<Pool<unknown>>,

    iter: (self: _Group<T...>) -> () -> (entity, T...)
}, {} :: {
    __len: (self: _Group<T...>) -> number,
    __iter: (self: _Group<T...>) -> () -> (entity, T...)
}))

function group_create<T...>(reg: Registry, data: GroupData, ...: T...): Group<T...>
    local pools = {}

    for i = 1, select("#", ...) do
        local ctype = select(i, ...)
        local pool = reg:storage(ctype)
        assert(table.find(data, pool), "component type is not in group")
        pools[i] = pool 
    end

    local function iter(self: _Group<T...>): () -> (entity, T...)
        local pools = self.pools
        local n = self.data.size
        local entities = pools[1].entities
    
        local values: Array<Array<unknown>> = table.create(#pools)
        for i, pool in next, pools do
            values[i] = pool.values
        end
    
        if #pools == 1 then
            local a = unpack(values)
            return function()
                local ia = n
                if ia == 0 then return NIL end
                local ib = ia - 1
                n = ib
                return BUFFER_GET(entities, ib), a[ia]  
            end
        elseif #pools == 2 then
            local a, b = unpack(values)
            return function()
                local ia = n
                if ia == 0 then return NIL end
                local ib = ia - 1
                n = ib
                return BUFFER_GET(entities, ib), a[ia], b[ia] 
            end
        elseif #pools == 3 then
            local a, b, c = unpack(values)
            return function()
                local ia = n
                if ia == 0 then return NIL end
                local ib = ia - 1
                n = ib
                return BUFFER_GET(entities, ib), a[ia], b[ia], c[ia]
            end
        elseif #pools == 4 then
            local a, b, c, d = unpack(values)
            return function()
                local ia = n
                if ia == 0 then return NIL end
                local ib = ia - 1
                n = ib
                return BUFFER_GET(entities, ib), a[ia], b[ia], c[ia], d[ia]
            end
        else
            local tuple = table.create(#values) :: Array<any>
            return function()
                local ia = n
                if ia == 0 then return NIL end
                local ib = ia - 1
                n = ib
                for pos, v in next, values do
                    tuple[pos] = v[ia]
                end
                return BUFFER_GET(entities, ib), unpack(tuple)
            end
        end
    end

    local self = {
        data = data,
        pools = pools,

        iter = iter,

        __len = function(self: _Group<T...>): number
            return self.data.size
        end,

        __iter = iter
    }

    setmetatable(self, self)

    return self :: _Group<T...>
end

end

--------------------------------------------------------------------------------
-- signal
--------------------------------------------------------------------------------

local signal_create: <T...>() -> (Signal<T...>, Array<(T...) -> ()>) do
    type _Signal<T...> = {
        listeners: Array<(T...) -> ()>,

        connect: (_Signal<T...>, (T...) -> ()) -> _Connection<T...>,
        on_empty: () -> ()?,
        on_not_empty: () -> ()?
    }
    
    type _Connection<T... = ...unknown> = {
        signal: _Signal<T...>,
        listener: (T...) -> (),
        connected: boolean,

        disconnect: (_Connection<T...>) -> (),
        reconnect: (_Connection<T...>) -> ()
    }

    local Connection = {}

    function Connection.new<T...>(signal: _Signal<T...>, fn: (T...) -> ()): _Connection<T...>
        return {
            signal = signal,
            listener = fn,
            connected = true,

            disconnect = function(self: _Connection<T...>)
                if self.connected then
                    local listeners = self.signal.listeners
                    local n = #listeners
                    local last = listeners[n]
                    local idx = table.find(listeners, fn)
                    assert(idx, "cannot find listener")

                    listeners[idx] = last
                    listeners[n] = nil

                    self.connected = false

                    if n == 1 and self.signal.on_empty then
                        self.signal.on_empty()
                    end

                end
            end,

            reconnect = function(self: _Connection<T...>)
                if not self.connected then
                    local new = self.signal:connect(self.listener)
                    self.idx = new.idx
                    self.connected = true
                end
            end
        }
    end

    local Signal = {}

    function Signal.new<T...>(): _Signal<T...>
        local self: _Signal<T...> = {
            listeners = {},


            on_empty = nil,
            on_not_empty = nil,

            connect = function(self: _Signal<T...>, listener: (T...) -> ()): _Connection<T...>
                local n = #self.listeners

                if n == 0 and self.on_not_empty then
                    self.on_not_empty()
                end

                self.listeners[n + 1] = listener

                return Connection.new(self, listener)
            end
        }

        return self
    end

    function signal_create<T...>(): Signal<T...>
        local signal = Signal.new()
        return signal :: any -- todo
    end
end

--------------------------------------------------------------------------------
-- handle
--------------------------------------------------------------------------------

local Handle = (function(): HandleMT
    local Handle = {}
    Handle.__index = Handle

    function Handle.destroy(self: Handle)
        self.world:destroy(self.entity)
    end

    function Handle.has_none(self: Handle): boolean
        return self.world:has_none(self.entity)
    end

    function Handle.add<T...>(self: Handle, ...: T...)
        self.world:add(self.entity, ...)
    end

    function Handle.set<T>(self: Handle, ctype: T, value: T): Handle
        self.world:set(self.entity, ctype, value)
        return self
    end

    function Handle.insert<T>(self: Handle, ctype: Array<T>, value: T): Handle
        self.world:insert(self.entity, ctype, value)
        return self
    end

    function Handle.patch<T>(self: Handle, ctype: T, fn: ((T) -> T)?): T
        return self.world:patch(self.entity, ctype, fn)
    end

    function Handle.has<T...>(self: Handle, ...: T...): boolean
        return self.world:has(self.entity, ...)
    end

    function Handle.get<T...>(self: Handle, ...: T...): T...
        return self.world:get(self.entity, ...)
    end

    function Handle.try_get<T>(self: Handle, ctype: T): T?
        return self.world:try_get(self.entity, ctype)
    end

    function Handle.remove<T...>(self: Handle, ...: T...)
        self.world:remove(self.entity, ...)
    end

    return Handle
end)()

--------------------------------------------------------------------------------
-- world
--------------------------------------------------------------------------------

local function world_create(range_start: number?, range_stop: number?): Registry
    local MAX_CTYPE = ctype_n

    if range_start then
        assert(range_stop)
        ASSERT(range_start > 0, "start of partition must be at least 1")
        ASSERT(range_stop >= range_start, "end of partition must be greater then start")
        ASSERT(range_stop <= ID_MAX_VALID_KEY, `end of partition cannot be greater than {ID_MAX_VALID_KEY}`)
    end

    local partition_start = range_start and range_start or 1
    local partition_stop = range_stop and range_stop or ID_MAX_VALID_KEY

    local world = {}

    local entity_list: EntityList = entity_list_create()
    local entity_pool = pool_create()

    local signals = {
        on_add = {} :: Map<CType, Signal<entity, unknown>>,
        on_change = {} :: Map<CType, Signal<entity, unknown>>,
        on_remove = {} :: Map<CType, Signal<entity, nil>>,
        on_clear = {} :: Map<CType, Signal<>>,
        after_clear = {} :: Map<CType, Signal<>>
    }
    
    local handle_cache = {} :: Map<entity?, Handle?>
    setmetatable(handle_cache :: any, { __mode = "v" })
    
    local ctype_pools: Map<CType, Pool<unknown>> = table.create(MAX_CTYPE)
    setmetatable(ctype_pools :: any, {
        __index = function(self, ctype: CType): Pool<unknown>
            ASSERT_CTYPE_VALID(ctype)
            ASSERT(ctype ~= ctype_entity, "attempt to use entity type")
            ASSERT((ctype :: number) <= MAX_CTYPE, `cannot use {ctype_debug(ctype)}, component must be created before world creation`)
            local pool = pool_create(1)
            self[ctype] = pool
            return pool
        end
    })

    local function STORAGE<T>(ctype: T): Pool<T>
        return ctype_pools[ctype] :: Pool<any>
    end

    local function group_init(...: any): GroupData
        local group = { size = 0, added = false, connections = {} }

        for i = 1, select("#", ...) do
            local ctype = select(i, ...)
            local pool = STORAGE(ctype)
            group[i] = pool
            pool.group = group

            table.insert(group.connections, world:on_add(ctype):connect(function(id)
                POOL_TRY_GROUP(pool, id)
            end))

            table.insert(group.connections, world:on_remove(ctype):connect(function(id)
                POOL_TRY_UNGROUP(pool, id)
            end))

            world:on_clear(ctype):connect(function()
                for _, cn in group.connections do cn:disconnect() end
            end)

            world:after_clear(ctype):connect(function()
                group.size = 0
                for _, cn in group.connections do cn:reconnect() end
            end)
        end

        local pool = STORAGE((...))
        for i = 0, pool.size - 1 do
            POOL_TRY_GROUP(pool, BUFFER_GET(pool.entities, i))
        end

        return group
    end

    local function ASSERT_VALID_ENTITY(id: entity)
        ASSERT(ENTITY_LIST_ID_IN_USE(entity_list, id), "invalid entity")
    end

    function world.create(self: Registry, desired_id: entity?): entity
        if not desired_id then
            if entity_list.free == ID_NULL_KEY then
                local old_capacity = entity_list.capacity
                local old_max = old_capacity - 1
                ASSERT(old_max < partition_stop, "cannot create entity; world is at max entities")

                local new_capacity = math.ceil((old_capacity + 1) * 1.5)
                local new_max = new_capacity - 1
                if new_max > partition_stop then 
                    new_capacity = partition_stop + 1
                elseif new_max < partition_start then
                    new_capacity = partition_start + 1
                end

                entity_list_resize(entity_list, new_capacity, partition_start, partition_stop)
            end

            assert(entity_list.free ~= ID_NULL_KEY)

            local new_key = entity_list.free
            local next_key_cur_ver = BUFFER_GET(entity_list.data, new_key)
            local new_id = ID_CREATE(new_key, ID_VER(next_key_cur_ver))

            BUFFER_SET(entity_list.data, new_key, new_id)
            entity_list.free = ID_KEY(next_key_cur_ver)

            POOL_RESIZE_MAP_IF_NEEDED(entity_pool, new_key)
            POOL_ADD_ID(entity_pool, new_id)

            return new_id
        else
            local desired_key = ID_KEY(desired_id)
            local desired_ver = ID_VER(desired_id)

            ASSERT(
                desired_id < ID_MAX and
                desired_key ~= ID_NULL_KEY and desired_key <= ID_MAX_VALID_KEY and
                desired_ver ~= ID_NULL_VER and desired_ver <= ID_MASK_VER,
                "malformed id"
            )

            if desired_key > entity_list.capacity - 1 then
                local new_capacity = (desired_id + 1) * 1.5
                if new_capacity - 1 > ID_MAX_VALID_KEY then new_capacity = ID_MAX_VALID_KEY + 1 end
                entity_list_resize(entity_list, new_capacity, partition_start, partition_stop)
            end

            ASSERT(BUFFER_GET(entity_list.data, desired_key) ~= desired_id, "unable to create entity; key is already in use")

            if entity_list.free == desired_key then
                entity_list.free = ID_KEY(BUFFER_GET(entity_list.data, desired_key))
            elseif BUFFER_GET(entity_list.data, desired_key) ~= ID_NULL then -- is somewhere along linked list
                local prev = entity_list_get_prev_key(entity_list, desired_key)
                BUFFER_SET(entity_list.data, prev, ID_CREATE( -- a -> b -> c, remove b, link a -> c
                    ID_KEY(BUFFER_GET(entity_list.data, desired_key)),
                    ID_VER(BUFFER_GET(entity_list.data, prev))
                ))
            end

            BUFFER_SET(entity_list.data, desired_key, desired_id)

            POOL_RESIZE_MAP_IF_NEEDED(entity_pool, desired_key)
            POOL_ADD_ID(entity_pool, desired_id)

            return desired_id
        end
    end

    function world.release(self: Registry, id: entity)
        ASSERT_VALID_ENTITY(id)
        if entity_pool.on_remove then fire(entity_pool.on_remove, id) end
        entity_list_remove(entity_list, id, partition_start, partition_stop)
        POOL_REMOVE(entity_pool, ID_KEY(id), id)
    end

    function world.destroy(self: Registry, id: entity)
        ASSERT_VALID_ENTITY(id)
        local key = ID_KEY(id)

        for _, pool in ctype_pools do
            if POOL_HAS(pool, key) then
                POOL_REMOVE(pool, key, id)
            end
        end

        if entity_pool.on_remove then fire(entity_pool.on_remove, id) end
        entity_list_remove(entity_list, id, partition_start, partition_stop)
        POOL_REMOVE(entity_pool, ID_KEY(id), id)
    end

    function world.contains(self: Registry, id: entity): boolean
        return ENTITY_LIST_ID_IN_USE(entity_list, id)
    end

    function world.has_none(self: Registry, id: entity): boolean
        ASSERT_VALID_ENTITY(id)
        local key = ID_KEY(id)

        for _, pool in next, ctype_pools do
            if POOL_HAS(pool, key) then return false end
        end

        return true
    end

    function world.add<T...>(self: Registry, id: entity, ...: T...)
        ASSERT_VALID_ENTITY(id)
        local key = ID_KEY(id)

        for i = 1, select("#", ...) do
            local ctype = select(i, ...)
            local pool = STORAGE(ctype)

            POOL_RESIZE_MAP_IF_NEEDED(pool, key)
            if BUFFER_GET(pool.map, key) ~= ID_NULL then continue end

            local ctor = ctype_ctors[ctype]

            if ctor == true then
                POOL_ADD_ID(pool, id)
            elseif ctor == false then
                throw(`no constructor defined for {ctype_debug(ctype, i)}`)
            else
                local value = (ctor :: () -> unknown)()
                if value == nil then throw(`{ctype_debug(ctype, i)} constructor did not return a value`) end   
                POOL_ADD(pool, id, value)
            end
        end
    end
    
    function world.set<T>(self: Registry, id: entity, ctype: T, value: T)        
        local pool = STORAGE(ctype)

        local key = ID_KEY(id)
        POOL_RESIZE_MAP_IF_NEEDED(pool, key)
        local idx_ver = BUFFER_GET(pool.map, key)

        if value ~= nil then -- valued component
            if idx_ver ~= ID_NULL then -- already added, change value
                ID_ASSERT_VERSION_EQUAL(idx_ver, id)
                if pool.on_change then fire(pool.on_change, id, value) end
                ARRAY_SET(pool.values, ID_KEY(idx_ver), value)
            else -- not added, add value
                ASSERT_VALID_ENTITY(id)
                POOL_ADD(pool, id, value)
            end
        else -- tag component
            ASSERT_VALID_ENTITY(id)
            ASSERT(ctype_is_tag(ctype), "cannot set component value to nil")
            if idx_ver ~= ID_NULL then return end
            POOL_ADD_ID(pool, id)
        end
    end

    function world.insert<T>(self: Registry, id: entity, ctype: Array<T>, value: T)
        local pool = STORAGE(ctype)

        local key = ID_KEY(id)
        POOL_RESIZE_MAP_IF_NEEDED(pool, key)
        local idx_ver = BUFFER_GET(pool.map, key)

        if idx_ver ~= ID_NULL then
            ID_ASSERT_VERSION_EQUAL(idx_ver, id)
            local idx = ID_KEY(idx_ver)
            local t = ARRAY_GET(pool.values, idx)
            table.insert(t, value)
            if pool.on_change then fire(pool.on_change, id, t) end
        else
            ASSERT_VALID_ENTITY(id)
            local t = {value}
            POOL_ADD(pool, id, t)
        end
    end
    
    function world.patch<T>(self: Registry, id: entity, ctype: T, fn: ((T) -> T)?): T
        local pool = STORAGE(ctype)

        local key = ID_KEY(id)
        POOL_RESIZE_MAP_IF_NEEDED(pool, key)
        local idx_ver = BUFFER_GET(pool.map, key)

        if idx_ver ~= ID_NULL then
            ID_ASSERT_VERSION_EQUAL(idx_ver, id)
            local idx = ID_KEY(idx_ver)
            if fn then
                local value = fn(ARRAY_GET(pool.values, idx))
                ASSERT(value ~= nil, "function cannot return nil")
                if pool.on_change then fire(pool.on_change, id, value) end
                ARRAY_SET(pool.values, idx, value)
                return value
            else
                local value = ARRAY_GET(pool.values, idx)
                if pool.on_change then fire(pool.on_change, id, value) end
                return value
            end
        else
            ASSERT_VALID_ENTITY(id)
            local ctor = ctype_ctors[ctype]
            if ctor == false or ctor == true then throw(`entity does not have component and no constructor for {ctype_debug(ctype)}`) end
            local value = (ctor :: () -> T)()
            if fn then value = fn(value) end
            ASSERT(value ~= nil, "function cannot return nil")
            POOL_ADD(pool, id, value)
            return value
        end
    end

    world.has = (function(self: Registry, id: entity, a, b, c, d, e): boolean
        local key = ID_KEY(id)
        local idx_ver = POOL_FIND(STORAGE(a), key)
        return
            idx_ver ~= ID_NULL and ID_VER(idx_ver) == ID_VER(id) and
            (b == nil or POOL_FIND(STORAGE(b), key) ~= ID_NULL) and
            (c == nil or POOL_FIND(STORAGE(c), key) ~= ID_NULL) and
            (d == nil or POOL_FIND(STORAGE(d), key) ~= ID_NULL) and
            (e == nil or throw("args exceeded") :: never)
    end :: any) :: <T...>(self: Registry, id: entity, T...) -> boolean

    local function UNSAFE_GET(ctype: CType, key: number): unknown
        local pool = STORAGE(ctype)
        local idx_ver = POOL_FIND(pool, key)
        if idx_ver == ID_NULL then throw("entity does not have " .. ctype_debug(ctype)) end
        return ARRAY_GET(pool.values, ID_KEY(idx_ver)) 
    end

    world.get = (function(self: Registry, id: entity, a, b, c, d, e): ...unknown
        local pool = STORAGE(a)
    
        local key = ID_KEY(id)
        local idx_ver = POOL_FIND(pool, key)
        if idx_ver == ID_NULL then throw(`entity does not have {ctype_debug(a, 1)}`) end

        ID_ASSERT_VERSION_EQUAL(idx_ver, id)
        local va = ARRAY_GET(pool.values, ID_KEY(idx_ver))

        if b == nil then
            return va
        elseif c == nil then
            return va, UNSAFE_GET(b, key)
        elseif d == nil then
            return va, UNSAFE_GET(b, key), UNSAFE_GET(c, key)
        elseif e == nil then
            return va, UNSAFE_GET(b, key), UNSAFE_GET(c, key), UNSAFE_GET(d, key)
        else throw("args exceeded") end
    end :: any) :: <T...>(self: Registry, id: entity, T...) -> T...

    function world.try_get<T>(self: Registry, id: entity, ctype: T): T?
        local pool = STORAGE(ctype)
        local idx_ver = POOL_FIND(pool, ID_KEY(id))
        if idx_ver == ID_NULL or ID_VERSION_NOT_EQUAL(idx_ver, id) then return nil end
        return ARRAY_GET(pool.values, ID_KEY(idx_ver))
    end

    function world.remove<T...>(self: Registry, id: entity, ...: T...)
        for i = 1, select("#", ...) do
            local pool = STORAGE(select(i, ...))
            POOL_TRY_REMOVE(pool, id)
        end
    end

    function world.clear<T...>(self: Registry, ...: T...)
        local argn = select("#", ...)
        if argn > 0 then
            for i = 1, argn do pool_clear(STORAGE(select(i, ...))) end
        else
            for _, pool in next, ctype_pools do pool_clear(pool) end
    
            pool_clear(entity_pool)
            entity_list_clear(entity_list, partition_start, partition_stop)
        end 
    end

    function world.find<T>(self: Registry, ctype: T, value: T): entity?
        local pool = STORAGE(ctype)

        if value == nil then
            if pool.size == 0 then return nil end
            return BUFFER_GET(pool.entities, 0)
        else
            local arr_idx = table.find(pool.values, value)
            return arr_idx and BUFFER_GET(pool.entities, arr_idx - 1)
        end
    end

    function world.copy<T>(self: Registry, copy: T, paste: T)
        local pool_a = STORAGE(copy)
        local pool_b = STORAGE(paste)

        POOL_COPY(pool_a, pool_b)
    end

    function world.query<T...>(self: Registry, ...: T...): View<T...>
        ASSERT(select("#", ...) > 0, "query must contain at least 1 component")
        return query_create(world, ...)
    end 

    function world.track<T...>(self: Registry, ...: T...): Observer<T...>
        ASSERT(select("#", ...) > 0, "observer must contain at least 1 component")
        return observer_create(world, ...)
    end

    world.group = nil :: any -- todo: why?
    function world.group<T...>(self: Registry, ...: T...): Group<T...>
        local argn = select("#", ...)
        ASSERT(argn > 1, "group must contain at least 2 components")
        local group = STORAGE((select(1, ...))).group :: GroupData<unknown>

        for i = 1, argn do
            local ctype = select(i, ...)
            ASSERT_CTYPE_VALID(ctype, i)
            ASSERT(STORAGE(ctype).group == group, `cannot create group; {ctype_debug(ctype, i)} is not owned by the same group as previous args`)
        end

        return group_create(world, group or group_init(...), ...)
    end

    local function STORAGE_OR_ENTITY_POOL<T>(ctype: T): Pool<T>
        return ctype == ctype_entity and entity_pool :: Pool<any> or STORAGE(ctype)
    end

    function world.storage<T>(self: Registry, ctype: T?): any
        if ctype == "list" then
            return entity_list
        elseif ctype then
            return STORAGE_OR_ENTITY_POOL(ctype)
        else
            return coroutine.wrap(function()
                for ctype, pool in next, ctype_pools do
                    coroutine.yield(ctype, pool)
                end
            end)
        end
    end

    function world.on_add<T>(self: Registry, ctype: T): Signal<entity, T>
        return (signals.on_add[ctype] or (function() 
            local signal = signal_create() :: any
            signals.on_add[ctype] = signal
            function signal.on_empty() STORAGE_OR_ENTITY_POOL(ctype).on_add = false end
            function signal.on_not_empty() STORAGE_OR_ENTITY_POOL(ctype).on_add = signal.listeners end
            return signal
        end)()) :: Signal<entity, T>
    end

    function world.on_change<T>(self: Registry, ctype: T): Signal<entity, T>
        return (signals.on_change[ctype] or (function() 
            local signal = signal_create() :: any
            signals.on_change[ctype] = signal
            function signal.on_empty() STORAGE_OR_ENTITY_POOL(ctype).on_change = false end
            function signal.on_not_empty() STORAGE_OR_ENTITY_POOL(ctype).on_change = signal.listeners end
            return signal    
        end)()) :: Signal<entity, T>    
    end

    function world.on_remove<T>(self: Registry, ctype: T): Signal<entity, nil>
        return signals.on_remove[ctype] or (function() 
            local signal = signal_create() :: any
            signals.on_remove[ctype] = signal
            function signal.on_empty() STORAGE_OR_ENTITY_POOL(ctype).on_remove = false end
            function signal.on_not_empty() STORAGE_OR_ENTITY_POOL(ctype).on_remove = signal.listeners end
            return signal
        end)() :: Signal<entity, nil>
    end

    function world.on_clear<T>(self: Registry, ctype: T): Signal<>
        return signals.on_clear[ctype] or (function() 
            local signal = signal_create() :: any
            signals.on_clear[ctype] = signal
            function signal.on_empty() STORAGE_OR_ENTITY_POOL(ctype).on_clear = false end
            function signal.on_not_empty() STORAGE_OR_ENTITY_POOL(ctype).on_clear = signal.listeners end
            return signal
        end)() :: Signal<>
    end

    function world.after_clear<T>(self: Registry, ctype: T): Signal<>
        return signals.after_clear[ctype] or (function() 
            local signal = signal_create() :: any
            signals.after_clear[ctype] = signal
            function signal.on_empty() STORAGE_OR_ENTITY_POOL(ctype).after_clear = false end
            function signal.on_not_empty() STORAGE_OR_ENTITY_POOL(ctype).after_clear = signal.listeners end
            return signal
        end)() :: Signal<>
    end

    function world.handle(self: Registry, id: entity?): Handle
        id = id or world:create()

        local handle = handle_cache[id]

        if not handle then
            handle = table.freeze(setmetatable({
                world = world,
                entity = id :: entity
            }, Handle))

            handle_cache[id] = handle
        end

        return assert(handle)
    end

    function world.context(self: Registry): Handle
        if not ENTITY_LIST_ID_IN_USE(entity_list, ID_CTX) then world:create(ID_CTX) end
        return world:handle(ID_CTX)  
    end

    return table.freeze(world)
end

--------------------------------------------------------------------------------
-- queue
--------------------------------------------------------------------------------

local Queue = {} do
    Queue.__index = Queue

    type _Queue = Queue<...any> & {
        size: number,
        columns: Array<Array<unknown>>
    }

    function Queue.new<T...>(): Queue<T...>
        local self: _Queue = setmetatable({
            size = 0,
            columns = {}
        }, Queue) :: any

        setmetatable(self.columns, {
            __index = function(columns: Array<Array<unknown>>, idx: number)
                columns[idx] = {}
                return columns[idx]
            end
        })

        return self :: Queue<T...>
    end

    function Queue.add(self: _Queue, ...: unknown)
        -- iteration will stop if first value is `nil`
        ASSERT((...) ~= nil, "first argument cannot be nil")

        local columns = self.columns
        local n = self.size + 1
        self.size = n

        for i = 1, select("#", ...) do
            columns[i][n] = select(i, ...)
        end
    end

    function Queue.clear(self: _Queue)
        self.size = 0
        for _, column in next, self.columns do
            table.clear(column)
        end
    end

    local function iter(self: _Queue)
        local columns = self.columns
        local n = self.size
        local i = 0

        if #columns <= 1 then
            local column = columns[1]
            return function()
                i += 1
                local value = column[i]
                if i == n then self:clear() end
                return value
            end
        else
            local tuple = table.create(#columns)
            return function()
                i += 1
                for ci, column in next, columns do
                    tuple[ci] = column[i]
                end
                if i == n then self:clear() end
                return unpack(tuple)
            end
        end
    end

    Queue.iter = function(self) return iter(self) end
    Queue.__iter = function(self) return iter(self) end

    function Queue.__len(self: _Queue)
        return self.size
    end
end

type ISignal<T...> = {
    connect: (self: any, listener: (T...) -> ()) -> ()
} | {
    Connect: (self: any, listener: (T...) -> ()) -> ()
} | (listener: (T...) -> ()) -> ()

local queue_create = function<T...>(signal: ISignal<T...>?): Queue<T...>
    local queue = Queue.new()

    if signal then
        local function listener(...: T...) queue:add(...) end

        if type(signal) == "function" then
            signal(listener)
        else
            local connector = (signal :: any).connect or (signal :: any).Connect
            ASSERT(connector, "signal has no member `connect()`")
            connector(signal, listener)
        end
    end

    return queue
end :: ( <T...>() -> Queue<T...> ) & ( <T...>(signal: ISignal<T...>) -> Queue<T...> )

--------------------------------------------------------------------------------
-- buffer util
--------------------------------------------------------------------------------

local function buffer_to_array(buf: buffer, size: number, arr: Array<entity>?): Array<entity>
    ASSERT(size * ID_SIZE <= buffer.len(buf), "buffer is smaller than given size")

    arr = arr or table.create(size); assert(arr)

    for i = 0, size - 1 do
        arr[i + 1] = BUFFER_GET(buf, i)
    end

    return arr
end

local function array_to_buffer(arr: Array<entity>, size: number, buf: buffer?): buffer
    buf = buf or buffer.create(size * ID_SIZE); assert(buf)

    ASSERT(size * ID_SIZE <= buffer.len(buf), "size is larger than buffer size")

    for i = 1, size do
        BUFFER_SET(buf, (i - 1), arr[i])
    end

    return buf
end

local function buffer_to_buffer(buf_src: buffer, size: number, buf_tar: buffer?): buffer
    buf_tar = buf_tar or buffer.create(size * ID_SIZE); assert(buf_tar)

    ASSERT(size * ID_SIZE <= buffer.len(buf_tar), "size is larger than buffer size")

    buffer.copy(buf_tar, 0, buf_src, 0, size * ID_SIZE)

    return buf_tar
end

--------------------------------------------------------------------------------
-- export
--------------------------------------------------------------------------------

local ecr = {
    world = world_create,

    component = function(constructor: () -> ()?)
        ASSERT(constructor == nil or type(constructor) == "function", "constructor must be a function")
        return ctype_create(constructor or false)
    end :: (() -> unknown) & (<T>(constructor: () -> T) -> T),

    tag = function() return ctype_create(true) end :: () -> nil,

    is_tag = function<T>(ctype: T): boolean
        ASSERT_CTYPE_VALID(ctype)
        return ctype_is_tag(ctype)
    end,
    
    name = function<T>(v: T): T | string?
        if type(v) == "table" then
            for name, ctype in next, v do
                ASSERT(CTYPE_VALID(ctype), `{name} refers to an invalid component`)
                ctype_set_name(ctype, name)
            end
            return v
        else
            ASSERT_CTYPE_VALID(v)
            return ctype_names[v]
        end
    end :: (<T>(names: T & {}) -> T) & (<T>(ctype: T) -> string?),
    
    queue = queue_create,
    
    array_to_buffer = array_to_buffer,
    buffer_to_array = buffer_to_array,
    buffer_to_buffer = buffer_to_buffer,

    is_pair = function() return false end,

    entity = ctype_entity,
    null = ID_NULL,
    context = ID_CTX,
    id_size = ID_SIZE,

    inspect = function(id: entity): (number, number)
        local key, ver = ID_KEY(id), ID_VER(id)
        return key, ver * ID_RSHIFT
    end,
    
    _test = {
        ver_shift = ID_LSHIFT,
        max_ver = ID_MASK_VER * ID_RSHIFT,
        max_creatable = ID_MASK_KEY - 1,

        create_id = function(key: number, ver: number)
            return ID_CREATE(key, ver * ID_LSHIFT)
        end,

        set_key_version = function(reg: Registry, key: number, ver: number)
            local list = reg:storage("list") :: any
            local key_ver = BUFFER_GET(list.data, key)
            if ENTITY_LIST_ID_IN_USE(list, key_ver) then ASSERT(false, "attempt to set version of in-use entity") end
            BUFFER_SET(list.data, key, ID_CREATE(ID_KEY(key_ver), ver * ID_LSHIFT))
        end,
    
        get_key_version = function(reg: Registry, key: number): number
            local list = reg:storage("list") :: any
            ASSERT(list.capacity > key, "not contained")
            return ID_VER(BUFFER_GET(list.data, key)) * ID_RSHIFT
        end
    }
}

return table.freeze(ecr)

