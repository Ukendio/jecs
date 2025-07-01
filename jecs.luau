
--!optimize 2
--!native
--!strict
--draft 4

type i53 = number
type i24 = number

type Ty = { Entity }
type ArchetypeId = number

type Column = { any }

type Map<K, V> = { [K]: V }

export type Archetype = {
	id: number,
	types: Ty,
	type: string,
	entities: { Entity },
	columns: { Column },
	columns_map: { [Id]: Column },
	dead: boolean,
}

export type QueryInner = {
	compatible_archetypes: { Archetype },
	ids: { i53 },
	filter_with: { i53 },
	filter_without: { i53 },
	next: () -> (number, ...any),
	world: World,
}

export type Entity<T = any> = number | { __T: T }
export type Id<T = any> = number | { __T: T }
export type Pair<P, O> = Id<P>
type ecs_id_t<T = unknown> = Id<T> | Pair<T, "Tag"> | Pair<"Tag", T>
export type Item<T...> = (self: Query<T...>) -> (Entity, T...)
export type Iter<T...> = (query: Query<T...>) -> () -> (Entity, T...)

export type Query<T...> = typeof(setmetatable(
	{} :: {
		iter: Iter<T...>,
		with: (self: Query<T...>, ...Id) -> Query<T...>,
		without: (self: Query<T...>, ...Id) -> Query<T...>,
		archetypes: (self: Query<T...>) -> { Archetype },
		cached: (self: Query<T...>) -> Query<T...>,
	},
	{} :: {
		__iter: Iter<T...>,
	}
))

type QueryArm<T...> = () -> ()

export type Observer = {
	callback: (archetype: Archetype) -> (),
	query: QueryInner,
}

export type World = {
	archetype_edges: Map<Entity, Map<Entity, Archetype>>,
	archetype_index: { [string]: Archetype },
	archetypes: Archetypes,
	component_index: ComponentIndex,
	entity_index: EntityIndex,
	ROOT_ARCHETYPE: Archetype,

	max_component_id: number,
	max_archetype_id: number,

	observable: Map<Id, Map<Id, { Observer }>>,

	--- Enforce a check on entities to be created within desired range
	range: (self: World, range_begin: number, range_end: number?) -> (),

	--- Creates a new entity
	entity: <T>(self: World, id: Entity<T>?) -> Entity<T>,
	--- Creates a new entity located in the first 256 ids.
	--- These should be used for static components for fast access.
	component: <T>(self: World) -> Entity<T>,
	--- Gets the target of an relationship. For example, when a user calls
	--- `world:target(id, ChildOf(parent), 0)`, you will obtain the parent entity.
	target: <T, a>(self: World, id: Entity<T>, relation: Id<a>, index: number?) -> Entity?,
	--- Deletes an entity and all it's related components and relationships.
	delete: <T>(self: World, id: Entity<T>) -> (),

	--- Adds a component to the entity with no value
	add: <T, a>(self: World, id: Entity<T>, component: Id<a>) -> (),
	--- Assigns a value to a component on the given entity
	set: <T, a>(self: World, id: Entity<T>, component: Id<a>, data: a) -> (),

	cleanup: (self: World) -> (),
	-- Clears an entity from the world
	clear: <a>(self: World, id: Id<a>) -> (),
	--- Removes a component from the given entity
	remove: <T, a>(self: World, id: Entity<T>, component: Id<a>) -> (),
	--- Retrieves the value of up to 4 components. These values may be nil.
	get: & (<T, a>(World, Entity<T>, Id<a>) -> a?)
		& (<T, a, b>(World, Entity<T>, Id<a>, Id<b>) -> (a?, b?))
		& (<T, a, b, c>(World, Entity<T>, Id<a>, Id<b>, Id<c>) -> (a?, b?, c?))
		& (<T, a, b, c, d>(World, Entity<T>, Id<a>, Id<b>, Id<c>, Id<d>) -> (a?, b?, c?, d?)),

	--- Returns whether the entity has the ID.
	has: (<T, a>(World, Entity<T>, Id<a>) -> boolean)
		& (<T, a, b>(World, Entity<T>, Id<a>, Id<a>) -> boolean)
		& (<T, a, b, c>(World, Entity<T>, Id<a>, Id<b>, Id<c>) -> boolean)
		& <T, a, b, c, d>(World, Entity<T>, Id<a>, Id<b>, Id<c>, Id<d>) -> boolean,

	--- Get parent (target of ChildOf relationship) for entity. If there is no ChildOf relationship pair, it will return nil.
	parent: <T>(self: World, entity: Entity<T>) -> Entity?,

	--- Checks if the world contains the given entity
	contains: <T>(self: World, entity: Entity<T>) -> boolean,

	--- Checks if the entity exists
	exists: <T>(self: World, entity: Entity<T>) -> boolean,

	each: <T>(self: World, id: Id<T>) -> () -> Entity,

	children: <T>(self: World, id: Id<T>) -> () -> Entity,

	--- Searches the world for entities that match a given query
	query: (<A>(World, Id<A>) -> Query<A>)
		& (<A, B>(World, Id<A>, Id<B>) -> Query<A, B>)
		& (<A, B, C>(World, Id<A>, Id<B>, Id<C>) -> Query<A, B, C>)
		& (<A, B, C, D>(World, Id<A>, Id<B>, Id<C>, Id<D>) -> Query<A, B, C, D>)
		& (<A, B, C, D, E>(World, Id<A>, Id<B>, Id<C>, Id<D>, Id<E>) -> Query<A, B, C, D, E>)
		& (<A, B, C, D, E, F>(World, Id<A>, Id<B>, Id<C>, Id<D>, Id<E>, Id<F>) -> Query<A, B, C, D, E, F>)
		& (<A, B, C, D, E, F, G>(
			World,
			Id<A>,
			Id<B>,
			Id<C>,
			Id<D>,
			Id<E>,
			Id<F>,
			Id<G>
		) -> Query<A, B, C, D, E, F, G>)
		& (<A, B, C, D, E, F, G, H>(
			World,
			Id<A>,
			Id<B>,
			Id<C>,
			Id<D>,
			Id<E>,
			Id<F>,
			Id<G>,
			Id<H>,
			...Id<any>
		) -> Query<A, B, C, D, E, F, G, H>),
}

export type Record = {
	archetype: Archetype,
	row: number,
	dense: i24,
}
export type ComponentRecord = {
	records: { [Id]: number },
	counts: { [Id]: number },
	flags: number,
	size: number,
	hooks: {
		on_add: (<T>(entity: Entity, id: Entity<T>, value: T?) -> ())?,
		on_change: (<T>(entity: Entity, id: Entity<T>, value: T) -> ())?,
		on_remove: ((entity: Entity, id: Entity) -> ())?,
	},
}
export type ComponentIndex = Map<Id, ComponentRecord>
export type Archetypes = { [Id]: Archetype }

export type EntityIndex = {
	dense_array: Map<number, Entity>,
	sparse_array: Map<i24, Record>,
	alive_count: number,
	max_id: number,
	range_begin: number?,
	range_end: number?,
}

-- stylua: ignore start

local ECS_ENTITY_MASK =       bit32.lshift(1, 24)
local ECS_GENERATION_MASK =   bit32.lshift(1, 16)
local ECS_PAIR_OFFSET = 	                 2^48

local ECS_ID_DELETE =                 	     0b0001
local ECS_ID_IS_TAG =                 	     0b0010
local ECS_ID_IS_EXCLUSIVE =                  0b0100
local ECS_ID_MASK =                   	     0b0000

local HI_COMPONENT_ID =                       256
local EcsOnAdd =             HI_COMPONENT_ID +  1
local EcsOnRemove =          HI_COMPONENT_ID +  2
local EcsOnChange =          HI_COMPONENT_ID +  3
local EcsWildcard =          HI_COMPONENT_ID +  4
local EcsChildOf =           HI_COMPONENT_ID +  5
local EcsComponent =         HI_COMPONENT_ID +  6
local EcsOnDelete =          HI_COMPONENT_ID +  7
local EcsOnDeleteTarget =    HI_COMPONENT_ID +  8
local EcsDelete =            HI_COMPONENT_ID +  9
local EcsRemove =            HI_COMPONENT_ID + 10
local EcsName =              HI_COMPONENT_ID + 11
local EcsOnArchetypeCreate = HI_COMPONENT_ID + 12
local EcsOnArchetypeDelete = HI_COMPONENT_ID + 13
local EcsExclusive =         HI_COMPONENT_ID + 14
local EcsRest =              HI_COMPONENT_ID + 15

local NULL_ARRAY = table.freeze({}) :: Column
local NULL = newproxy(false)

local ECS_INTERNAL_ERROR = [[
	This is an internal error, please file a bug report via the following link:

	https://github.com/Ukendio/jecs/issues/new?template=BUG-REPORT.md
]]

local function ecs_assert(condition, msg: string?)
	if not condition then
		error(msg)
	end
end

local ecs_metadata: Map<i53, Map<i53, any>> = {}
local ecs_max_component_id = 0
local ecs_max_tag_id = EcsRest

local function ECS_COMPONENT()
	ecs_max_component_id += 1
	if ecs_max_component_id > HI_COMPONENT_ID then
		error("Too many components")
	end
	return ecs_max_component_id
end

local function ECS_TAG()
	ecs_max_tag_id += 1
	return ecs_max_tag_id
end

local function ECS_META(id: i53, ty: i53, value: any?)
	local bundle = ecs_metadata[id]
	if bundle == nil then
		bundle = {}
		ecs_metadata[id] = bundle
	end
	bundle[ty] = if value == nil then NULL else value
end

local function ECS_META_RESET()
	ecs_metadata = {}
	ecs_max_component_id = 0
	ecs_max_tag_id = EcsRest
end

local function ECS_COMBINE(id: number, generation: number): i53
	return id + (generation * ECS_ENTITY_MASK)
end

local function ECS_IS_PAIR(e: number): boolean
	return e > ECS_PAIR_OFFSET
end

local function ECS_GENERATION_INC(e: i53): i53
	if e > ECS_ENTITY_MASK then
		local id = e % ECS_ENTITY_MASK
		local generation = e // ECS_ENTITY_MASK

		local next_gen = generation + 1
		if next_gen >= ECS_GENERATION_MASK then
			return id
		end

		return ECS_COMBINE(id, next_gen)
	end
	return ECS_COMBINE(e, 1)
end

local function ECS_ENTITY_T_LO(e: i53): i24
	return e % ECS_ENTITY_MASK
end

local function ECS_ID(e: i53)
	return e % ECS_ENTITY_MASK
end

local function ECS_GENERATION(e: i53)
	return e // ECS_ENTITY_MASK
end

local function ECS_ENTITY_T_HI(e: i53): i24
	return e // ECS_ENTITY_MASK
end

local function ECS_PAIR(pred: i53, obj: i53): i53
	pred %= ECS_ENTITY_MASK
	obj %= ECS_ENTITY_MASK

	return obj + (pred * ECS_ENTITY_MASK) + ECS_PAIR_OFFSET
end

local function ECS_PAIR_FIRST(e: i53): i24
	return (e - ECS_PAIR_OFFSET) // ECS_ENTITY_MASK
end

local function ECS_PAIR_SECOND(e: i53): i24
	return (e - ECS_PAIR_OFFSET) % ECS_ENTITY_MASK
end

local function entity_index_try_get_any(
	entity_index: EntityIndex,
	entity: number
): Record?
	local r = entity_index.sparse_array[ECS_ENTITY_T_LO(entity)]

	if not r or r.dense == 0 then
		return nil
	end

	return r
end

local function entity_index_try_get(entity_index: EntityIndex, entity: Entity): Record?
	local r = entity_index_try_get_any(entity_index, entity :: number)
	if r then
		local r_dense = r.dense
		if r_dense > entity_index.alive_count then
			return nil
		end
		if entity_index.dense_array[r_dense] ~= entity then
			return nil
		end
	end
	return r
end

local function entity_index_is_alive<T>(entity_index: EntityIndex, entity: Entity<T>): boolean
	return entity_index_try_get(entity_index, entity) ~= nil
end

local function entity_index_get_alive<T>(entity_index: EntityIndex, entity: Entity<T>): Entity<T>?
	local r = entity_index_try_get_any(entity_index, entity :: number)
	if r then
		return entity_index.dense_array[r.dense]
	end
	return nil
end

local function ecs_get_alive<T>(world: World, entity: Entity<T>): Entity
	if entity == 0 then
		return 0
	end

	local eindex = world.entity_index

	if entity_index_is_alive(eindex, entity) then
		return entity
	end

	if (entity :: number) > ECS_ENTITY_MASK then
		return 0
	end

	local current = entity_index_get_alive(eindex, entity)
	if not current or not entity_index_is_alive(eindex, current) then
		return 0
	end

	return current
end

local ECS_INTERNAL_ERROR_INCOMPATIBLE_ENTITY = "Entity is outside range"

local function entity_index_new_id(entity_index: EntityIndex): Entity
	local dense_array = entity_index.dense_array
	local alive_count = entity_index.alive_count
	local sparse_array = entity_index.sparse_array
	local max_id = entity_index.max_id

	if alive_count < max_id then
		alive_count += 1
		entity_index.alive_count = alive_count
		local id = dense_array[alive_count]
		return id
	end

	local id = max_id + 1
	local range_end = entity_index.range_end
	ecs_assert(range_end == nil or id < range_end, ECS_INTERNAL_ERROR_INCOMPATIBLE_ENTITY)

	entity_index.max_id = id
	alive_count += 1
	entity_index.alive_count = alive_count
	dense_array[alive_count] = id
	sparse_array[id] = { dense = alive_count } :: Record

	return id
end

local function ecs_pair_first(world: World, e: i53)
	local pred = ECS_PAIR_FIRST(e)
	return ecs_get_alive(world, pred)
end

local function ecs_pair_second(world: World, e: i53)
	local obj = ECS_PAIR_SECOND(e)
	return ecs_get_alive(world, obj)
end

local function query_match(query: QueryInner, archetype: Archetype)
	local columns_map = archetype.columns_map
	local with = query.filter_with

	for _, id in with do
		if not columns_map[id] then
			return false
		end
	end

	local without = query.filter_without
	if without then
		for _, id in without do
			if columns_map[id] then
				return false
			end
		end
	end

	return true
end

local function find_observers(world: World, event: Id, component: Id): { Observer }?
	local cache = world.observable[event]
	if not cache then
		return nil
	end
	return cache[component] :: any
end

local function archetype_move(
	entity_index: EntityIndex,
	entity: Entity,
	to: Archetype,
	dst_row: i24,
	from: Archetype,
	src_row: i24
)
	local src_columns = from.columns
	local dst_entities = to.entities
	local src_entities = from.entities

	local last = #src_entities
	local id_types = from.types
	local columns_map = to.columns_map

	if src_row ~= last then
		-- If the entity is the last row in the archetype then swapping it would be meaningless.

		for i, column in src_columns do
			if column == NULL_ARRAY then
				continue
			end
			-- Retrieves the new column index from the source archetype's record from each component
			-- We have to do this because the columns are tightly packed and indexes may not correspond to each other.
			local dst_column = columns_map[id_types[i]]

			-- Sometimes target column may not exist, e.g. when you remove a component.
			if dst_column then
				dst_column[dst_row] = column[src_row]
			end

			-- Swap rempves columns to ensure there are no holes in the archetype.
			column[src_row] = column[last]
			column[last] = nil
		end


		-- Move the entity from the source to the destination archetype.
		-- Because we have swapped columns we now have to update the records
		-- corresponding to the entities' rows that were swapped.

		local e2 = src_entities[last]
		src_entities[src_row] = e2

		local sparse_array = entity_index.sparse_array
		local record2 = sparse_array[ECS_ENTITY_T_LO(e2 :: number)]
		record2.row = src_row
	else
		for i, column in src_columns do
			if column == NULL_ARRAY then
				continue
			end
			-- Retrieves the new column index from the source archetype's record from each component
			-- We have to do this because the columns are tightly packed and indexes may not correspond to each other.
			local dst_column = columns_map[id_types[i]]

			-- Sometimes target column may not exist, e.g. when you remove a component.
			if dst_column then
				dst_column[dst_row] = column[src_row]
			end

			column[last] = nil
		end
	end

	src_entities[last] = nil :: any
	dst_entities[dst_row] = entity
end

local function archetype_append(
	entity: Entity,
	archetype: Archetype
): number
	local entities = archetype.entities
	local length = #entities + 1
	entities[length] = entity
	return length
end

local function new_entity(
	entity: Entity,
	record: Record,
	archetype: Archetype
): Record
	local row = archetype_append(entity, archetype)
	record.archetype = archetype
	record.row = row
	return record
end

local function entity_move(
	entity_index: EntityIndex,
	entity: Entity,
	record: Record,
	to: Archetype
)
	local sourceRow = record.row
	local from = record.archetype
	local dst_row = archetype_append(entity, to)
	archetype_move(entity_index, entity, to, dst_row, from, sourceRow)
	record.archetype = to
	record.row = dst_row
end

local function hash(arr: { Entity }): string
	return table.concat(arr, "_")
end

local function fetch(id: Id, columns_map: { [Entity]: Column }, row: number): any
	local column = columns_map[id]

	if not column then
		return nil
	end

	return column[row]
end

local function world_get(world: World, entity: Entity,
	a: Id, b: Id?, c: Id?, d: Id?, e: Id?): ...any
	local record = entity_index_try_get(world.entity_index, entity)
	if not record then
		return nil
	end

	local archetype = record.archetype
	if not archetype then
		return nil
	end

	local columns_map = archetype.columns_map
	local row = record.row

	local va = fetch(a, columns_map, row)

	if not b then
		return va
	elseif not c then
		return va, fetch(b, columns_map, row)
	elseif not d then
		return va, fetch(b, columns_map, row), fetch(c, columns_map, row)
	elseif not e then
		return va, fetch(b, columns_map, row), fetch(c, columns_map, row), fetch(d, columns_map, row)
	else
		error("args exceeded")
	end
end

local function world_has_one_inline(world: World, entity: Entity, id: i53): boolean
	local record = entity_index_try_get(world.entity_index, entity)
	if not record then
		return false
	end

	local archetype = record.archetype
	if not archetype then
		return false
	end

	return archetype.columns_map[id] ~= nil
end

local function world_target(world: World, entity: Entity, relation: Id, index: number?): Entity?
	local entity_index = world.entity_index
	local record = entity_index_try_get(entity_index, entity)
	if not record then
		return nil
	end

	local archetype = record.archetype
	if not archetype then
		return nil
	end

	local r = ECS_PAIR(relation :: number, EcsWildcard)
	local idr = world.component_index[r]

	if not idr then
		return nil
	end

	local archetype_id = archetype.id
	local count = idr.counts[archetype_id]
	if not count then
		return nil
	end

	local nth = index or 0

	if nth >= count then
		nth = nth + count + 1
	end

	nth = archetype.types[nth + idr.records[archetype_id]]

	if not nth then
		return nil
	end

	return entity_index_get_alive(entity_index,
	    ECS_PAIR_SECOND(nth :: number))
end

local function ECS_ID_IS_WILDCARD(e: i53): boolean
	local first = ECS_ENTITY_T_HI(e)
	local second = ECS_ENTITY_T_LO(e)
	return first == EcsWildcard or second == EcsWildcard
end

local function id_record_get(world: World, id: Entity): ComponentRecord?
	local component_index = world.component_index
	local idr: ComponentRecord = component_index[id]

	if idr then
		return idr
	end

	return nil
end

local function id_record_ensure(world: World, id: Entity): ComponentRecord
	local component_index = world.component_index
	local entity_index = world.entity_index
	local idr: ComponentRecord? = component_index[id]

	if idr then
		return idr
	end

	local flags = ECS_ID_MASK
	local relation = id
	local target = 0
	local is_pair = ECS_IS_PAIR(id :: number)

	local has_delete = false
	local is_exclusive = false

	if is_pair then
		relation = entity_index_get_alive(entity_index, ECS_PAIR_FIRST(id :: number)) :: i53
		ecs_assert(relation and entity_index_is_alive(
			entity_index, relation), ECS_INTERNAL_ERROR)
		target = entity_index_get_alive(entity_index, ECS_PAIR_SECOND(id :: number)) :: i53
		ecs_assert(target and entity_index_is_alive(
			entity_index, target), ECS_INTERNAL_ERROR)

		local cleanup_policy_target = world_target(world, relation, EcsOnDeleteTarget, 0)

		if cleanup_policy_target == EcsDelete then
			has_delete = true
		end

		if world_has_one_inline(world, relation, EcsExclusive) then
			is_exclusive = true
		end
	else
		local cleanup_policy = world_target(world, relation, EcsOnDelete, 0)

		if cleanup_policy == EcsDelete then
			has_delete = true
		end
	end

	local on_add, on_change, on_remove = world_get(world,
		relation, EcsOnAdd, EcsOnChange, EcsOnRemove)

	local is_tag = not world_has_one_inline(world,
		relation, EcsComponent)

	if is_tag and is_pair then
		is_tag = not world_has_one_inline(world, target, EcsComponent)
	end

	flags = bit32.bor(
		flags,
		if has_delete then ECS_ID_DELETE else 0,
		if is_tag then ECS_ID_IS_TAG else 0,
		if is_exclusive then ECS_ID_IS_EXCLUSIVE else 0
	)

	idr = {
		size = 0,
		records = {},
		counts = {},
		flags = flags,
		hooks = {
			on_add = on_add,
			on_change = on_change,
			on_remove = on_remove,
		},
	} :: ComponentRecord

	component_index[id] = idr

	return idr
end

local function archetype_append_to_records(
	idr: ComponentRecord,
	archetype_id: number,
	columns_map: { [Id]: Column },
	id: i53,
	index: number,
	column: Column
)
	local idr_records = idr.records
	local idr_counts = idr.counts
	local tr = idr_records[archetype_id]
	if not tr then
		idr_records[archetype_id] = index
		idr_counts[archetype_id] = 1
		columns_map[id] = column
	else
		local max_count = idr_counts[archetype_id] + 1
		idr_counts[archetype_id] = max_count
	end
end

local function archetype_register(world: World, archetype: Archetype)
	local archetype_id = archetype.id
	local columns_map = archetype.columns_map
	local columns = archetype.columns
	for i, component_id in archetype.types do
		local idr = id_record_ensure(world, component_id)
		local is_tag = bit32.btest(idr.flags, ECS_ID_IS_TAG)
		local column = if is_tag then NULL_ARRAY else {}
		columns[i] = column

		archetype_append_to_records(idr, archetype_id, columns_map, component_id :: number, i, column)

		if ECS_IS_PAIR(component_id :: number) then
			local relation = ECS_PAIR_FIRST(component_id :: number)
			local object = ECS_PAIR_SECOND(component_id :: number)
			local r = ECS_PAIR(relation, EcsWildcard)
			local idr_r = id_record_ensure(world, r)

			archetype_append_to_records(idr_r, archetype_id, columns_map, r, i, column)

			local t = ECS_PAIR(EcsWildcard, object)
			local idr_t = id_record_ensure(world, t)

			archetype_append_to_records(idr_t, archetype_id, columns_map, t, i, column)
		end
	end
end

local function archetype_create(world: World, id_types: { Id }, ty, prev: i53?): Archetype
	local archetype_id = (world.max_archetype_id :: number) + 1
	world.max_archetype_id = archetype_id

	local length = #id_types
	local columns = (table.create(length) :: any) :: { Column }

	local columns_map: { [Id]: Column } = {}

	local archetype: Archetype = {
		columns = columns,
		columns_map = columns_map,
		entities = {},
		id = archetype_id,
		type = ty,
		types = id_types,
		dead = false,
	}

	archetype_register(world, archetype)

	for id in columns_map do
		local observer_list = find_observers(world, EcsOnArchetypeCreate, id)
		if not observer_list then
			continue
		end
		for _, observer in observer_list do
			if query_match(observer.query :: QueryInner, archetype) then
				observer.callback(archetype)
			end
		end
	end

	world.archetype_index[ty] = archetype
	world.archetypes[archetype_id] = archetype
	world.archetype_edges[archetype.id] = {} :: Map<Id, Archetype>

	return archetype
end

local function world_range(world: World, range_begin: number, range_end: number?)
	local entity_index = world.entity_index

	entity_index.range_begin = range_begin
	entity_index.range_end = range_end

	local max_id = entity_index.max_id

	if range_begin > max_id then
		local dense_array = entity_index.dense_array
		local sparse_array = entity_index.sparse_array

		for i = max_id + 1, range_begin do
			dense_array[i] = i
			sparse_array[i] = {
				dense = 0
			} :: Record
		end
		entity_index.max_id = range_begin - 1
		entity_index.alive_count = range_begin - 1
	end
end

local function archetype_ensure(world: World, id_types: { Id }): Archetype
	if #id_types < 1 then
		return world.ROOT_ARCHETYPE
	end

	local ty = hash(id_types)
	local archetype = world.archetype_index[ty]
	if archetype then
		if archetype.dead then
			archetype_register(world, archetype)
			archetype.dead = false :: any
		end
		return archetype
	end

	return archetype_create(world, id_types, ty)
end

local function find_insert(id_types: { i53 }, toAdd: i53): number
	for i, id in id_types do
		if id == toAdd then
			return -1
		end
		if id > toAdd then
			return i
		end
	end
	return #id_types + 1
end

local function find_archetype_without(
	world: World,
	node: Archetype,
	id: Id
): Archetype
	local id_types = node.types
	local at = table.find(id_types, id)

	local dst = table.clone(id_types)
	table.remove(dst, at)

	return archetype_ensure(world, dst)
end


local function create_edge_for_remove(
	world: World,
	node: Archetype,
	edge: Map<Id, Archetype>,
	id: Id
): Archetype
	local to = find_archetype_without(world, node, id)
	local edges = world.archetype_edges
	local archetype_id = node.id
	edges[archetype_id][id] = to
	edges[to.id][id] = node
	return to
end

local function archetype_traverse_remove(
	world: World,
	id: Id,
	from: Archetype
): Archetype
	local edges = world.archetype_edges
	local edge = edges[from.id]

	local to: Archetype = edge[id]
	if to == nil then
		to = find_archetype_without(world, from, id)
		edge[id] = to
		edges[to.id][id] = from
	end

	return to
end

local function find_archetype_with(world: World, id: Id, from: Archetype): Archetype
	local id_types = from.types
	local dst = table.clone(id_types)

	if ECS_IS_PAIR(id::number) then
		local first = ECS_PAIR_FIRST(id::number)
		local idr = world.component_index[ECS_PAIR(first, EcsWildcard)]
		if idr and bit32.btest(idr.flags, EcsExclusive) then
			local cr = idr.records[from.id]
			dst[cr] = id
			return archetype_ensure(world, dst)
		end
	end

	local at = find_insert(id_types :: { number } , id :: number)

	table.insert(dst, at, id)

	return archetype_ensure(world, dst)
end

local function archetype_traverse_add(world: World, id: Id, from: Archetype): Archetype
	from = from or world.ROOT_ARCHETYPE
	if from.columns_map[id] then
		return from
	end
	local edges = world.archetype_edges
	local edge = edges[from.id]

	local to = edge[id]
	if not to then
		to = find_archetype_with(world, id, from)
		edge[id] = to
		edges[to.id][id] = from
	end

	return to
end

local function world_component(world: World): i53
	local id = (world.max_component_id :: number) + 1
	if id > HI_COMPONENT_ID then
		-- IDs are partitioned into ranges because component IDs are not nominal,
		-- so it needs to error when IDs intersect into the entity range.
		error("Too many components, consider using world:entity() instead to create components.")
	end
	world.max_component_id = id

	return id
end



local function archetype_fast_delete_last(columns: { Column }, column_count: number)
	for i, column in columns do
		if column ~= NULL_ARRAY then
			column[column_count] = nil
		end
	end
end

local function archetype_fast_delete(columns: { Column }, column_count: number, row: number)
	for i, column in columns do
		if column ~= NULL_ARRAY then
			column[row] = column[column_count]
			column[column_count] = nil
		end
	end
end

local function archetype_delete(world: World, archetype: Archetype, row: number)
	local entity_index = world.entity_index
	local component_index = world.component_index
	local columns = archetype.columns
	local id_types = archetype.types
	local entities = archetype.entities
	local column_count = #entities
	local last = #entities
	local move = entities[last]
	-- We assume first that the entity is the last in the archetype
	local delete = move

	if row ~= last then
		local record_to_move = entity_index_try_get_any(entity_index, move :: number)
		if record_to_move then
			record_to_move.row = row
		end

		delete = entities[row]
		entities[row] = move
	end

	for _, id in id_types do
		local idr = component_index[id]
		local on_remove = idr.hooks.on_remove
		if on_remove then
			on_remove(delete, id)
		end
	end

	entities[last] = nil :: any

	if row == last then
		archetype_fast_delete_last(columns, column_count)
	else
		archetype_fast_delete(columns, column_count, row)
	end
end


local function archetype_destroy(world: World, archetype: Archetype)
	if archetype == world.ROOT_ARCHETYPE then
		return
	end

	local component_index = world.component_index
	local archetype_edges = world.archetype_edges

	for id, edge in archetype_edges[archetype.id] do
		archetype_edges[edge.id][id] = nil
	end

	local archetype_id = archetype.id
	world.archetypes[archetype_id] = nil :: any
	world.archetype_index[archetype.type] = nil :: any
	local columns_map = archetype.columns_map

	for id in columns_map do
		local observer_list = find_observers(world, EcsOnArchetypeDelete, id)
		if not observer_list then
			continue
		end
		for _, observer in observer_list do
			if query_match(observer.query, archetype) then
				observer.callback(archetype)
			end
		end
	end

	for id in columns_map do
		local idr = component_index[id]
		idr.records[archetype_id] = nil :: any
		idr.counts[archetype_id] = nil
		idr.size -= 1
		if idr.size == 0 then
			component_index[id] = nil :: any
		end
	end
end

local function NOOP() end


local function query_iter_init(query: QueryInner): () -> (number, ...any)
	local world_query_iter_next

	local compatible_archetypes = query.compatible_archetypes
	local lastArchetype = 1
	local archetype = compatible_archetypes[1]
	if not archetype then
		return NOOP :: () -> (number, ...any)
	end
	local entities = archetype.entities
	local i = #entities
	local columns_map = archetype.columns_map

	local ids = query.ids
	local A, B, C, D, E, F, G, H, I = unpack(ids)
	local a: Column, b: Column, c: Column, d: Column
	local e: Column, f: Column, g: Column, h: Column

	if not B then
		a = columns_map[A]
	elseif not C then
		a = columns_map[A]
		b = columns_map[B]
	elseif not D then
		a = columns_map[A]
		b = columns_map[B]
		c = columns_map[C]
	elseif not E then
		a = columns_map[A]
		b = columns_map[B]
		c = columns_map[C]
		d = columns_map[D]
	elseif not F then
		a = columns_map[A]
		b = columns_map[B]
		c = columns_map[C]
		d = columns_map[D]
		e = columns_map[E]
	elseif not G then
		a = columns_map[A]
		b = columns_map[B]
		c = columns_map[C]
		d = columns_map[D]
		e = columns_map[E]
		f = columns_map[F]
	elseif not H then
		a = columns_map[A]
		b = columns_map[B]
		c = columns_map[C]
		d = columns_map[D]
		e = columns_map[E]
		f = columns_map[F]
		g = columns_map[G]
	else
		a = columns_map[A]
		b = columns_map[B]
		c = columns_map[C]
		d = columns_map[D]
		e = columns_map[E]
		f = columns_map[F]
		g = columns_map[G]
		h = columns_map[H]
	end

	if not B then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns_map = archetype.columns_map
				a = columns_map[A]
			end

			local row = i
			i -= 1

			return entity, a[row]
		end
	elseif not C then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns_map = archetype.columns_map
				a = columns_map[A]
				b = columns_map[B]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row]
		end
	elseif not D then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns_map = archetype.columns_map
				a = columns_map[A]
				b = columns_map[B]
				c = columns_map[C]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row]
		end
	elseif not E then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns_map = archetype.columns_map
				a = columns_map[A]
				b = columns_map[B]
				c = columns_map[C]
				d = columns_map[D]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row]
		end
	elseif not F then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns_map = archetype.columns_map
				a = columns_map[A]
				b = columns_map[B]
				c = columns_map[C]
				d = columns_map[D]
				e = columns_map[E]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row], e[row]
		end
	elseif not G then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns_map = archetype.columns_map
				a = columns_map[A]
				b = columns_map[B]
				c = columns_map[C]
				d = columns_map[D]
				e = columns_map[E]
				f = columns_map[F]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row], e[row], f[row]
		end
	elseif not H then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns_map = archetype.columns_map
				a = columns_map[A]
				b = columns_map[B]
				c = columns_map[C]
				d = columns_map[D]
				e = columns_map[E]
				f = columns_map[F]
				g = columns_map[G]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row], e[row], f[row], g[row]
		end
	elseif not I then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns_map = archetype.columns_map
				a = columns_map[A]
				b = columns_map[B]
				c = columns_map[C]
				d = columns_map[D]
				e = columns_map[E]
				f = columns_map[F]
				g = columns_map[G]
				h = columns_map[H]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row], e[row], f[row], g[row], h[row]
		end
	else
		local output = {}
		local ids_len = #ids
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns_map = archetype.columns_map
				a = columns_map[A]
				b = columns_map[B]
				c = columns_map[C]
				d = columns_map[D]
				e = columns_map[E]
				f = columns_map[F]
				g = columns_map[G]
				h = columns_map[H]
			end

			local row = i
			i -= 1

			for i = 9, ids_len do
				output[i - 8] = columns_map[i][row]
			end

			return entity, a[row], b[row], c[row], d[row], e[row], f[row], g[row], h[row], unpack(output)
		end
	end

	query.next = world_query_iter_next
	return world_query_iter_next
end

local function query_iter(query): () -> (number, ...any)
	local query_next = query.next
	if not query_next then
		query_next = query_iter_init(query)
	end
	return query_next
end

local function query_without(query: QueryInner, ...: i53)
	local without = { ... }
	query.filter_without = without
	local compatible_archetypes = query.compatible_archetypes
	for i = #compatible_archetypes, 1, -1 do
		local archetype = compatible_archetypes[i]
		local columns_map = archetype.columns_map
		local matches = true

		for _, id in without do
			if columns_map[id] then
				matches = false
				break
			end
		end

		if matches then
			continue
		end

		local last = #compatible_archetypes
		if last ~= i then
			compatible_archetypes[i] = compatible_archetypes[last]
		end
		compatible_archetypes[last] = nil :: any
	end

	return query :: any
end

local function query_with(query: QueryInner, ...: i53)
	local compatible_archetypes = query.compatible_archetypes
	local with = { ... }
	query.filter_with = with

	for i = #compatible_archetypes, 1, -1 do
		local archetype = compatible_archetypes[i]
		local columns_map = archetype.columns_map
		local matches = true

		for _, id in with do
			if not columns_map[id] then
				matches = false
				break
			end
		end

		if matches then
			continue
		end

		local last = #compatible_archetypes
		if last ~= i then
			compatible_archetypes[i] = compatible_archetypes[last]
		end
		compatible_archetypes[last] = nil :: any
	end

	return query :: any
end

-- Meant for directly iterating over archetypes to minimize
-- function call overhead. Should not be used unless iterating over
-- hundreds of thousands of entities in bulk.
local function query_archetypes(query)
	return query.compatible_archetypes
end

local function query_cached(query: QueryInner)
	local with = query.filter_with
	local ids = query.ids
	if with then
		table.move(ids, 1, #ids, #with + 1, with)
	else
		query.filter_with = ids
	end

	local compatible_archetypes = query.compatible_archetypes
	local lastArchetype = 1

	local A, B, C, D, E, F, G, H, I = unpack(ids)
	local a: Column, b: Column, c: Column, d: Column
	local e: Column, f: Column, g: Column, h: Column

	local world_query_iter_next
	local entities: { Entity }
	local i: number
	local archetype: Archetype
	local columns_map: { [Id]: Column }
	local archetypes = query.compatible_archetypes

	local world = query.world
	-- Only need one observer for EcsArchetypeCreate and EcsArchetypeDelete respectively
	-- because the event will be emitted for all components of that Archetype.
	local observable = world.observable
	local on_create_action = observable[EcsOnArchetypeCreate]
	if not on_create_action then
		on_create_action = {} :: Map<Id, { Observer }>
		observable[EcsOnArchetypeCreate] = on_create_action
	end
	local query_cache_on_create = on_create_action[A]
	if not query_cache_on_create then
		query_cache_on_create = {}
		on_create_action[A] = query_cache_on_create
	end

	local on_delete_action = observable[EcsOnArchetypeDelete]
	if not on_delete_action then
		on_delete_action = {} :: Map<Id, { Observer }>
		observable[EcsOnArchetypeDelete] = on_delete_action
	end
	local query_cache_on_delete = on_delete_action[A]
	if not query_cache_on_delete then
		query_cache_on_delete = {}
		on_delete_action[A] = query_cache_on_delete
	end

	local function on_create_callback(archetype)
		table.insert(archetypes, archetype)
	end

	local function on_delete_callback(archetype)
		local i = table.find(archetypes, archetype) :: number
		if i == nil then
			return
		end
		local n = #archetypes
		archetypes[i] = archetypes[n]
		archetypes[n] = nil
	end

	local observer_for_create = { query = query, callback = on_create_callback }
	local observer_for_delete = { query = query, callback = on_delete_callback }

	table.insert(query_cache_on_create, observer_for_create)
	table.insert(query_cache_on_delete, observer_for_delete)

	local function cached_query_iter()
		lastArchetype = 1
		archetype = compatible_archetypes[lastArchetype]
		if not archetype then
			return NOOP
		end
		entities = archetype.entities
		i = #entities
		columns_map = archetype.columns_map
		if not B then
			a = columns_map[A]
		elseif not C then
			a = columns_map[A]
			b = columns_map[B]
		elseif not D then
			a = columns_map[A]
			b = columns_map[B]
			c = columns_map[C]
		elseif not E then
			a = columns_map[A]
			b = columns_map[B]
			c = columns_map[C]
			d = columns_map[D]
		elseif not F then
			a = columns_map[A]
			b = columns_map[B]
			c = columns_map[C]
			d = columns_map[D]
			e = columns_map[E]
		elseif not G then
			a = columns_map[A]
			b = columns_map[B]
			c = columns_map[C]
			d = columns_map[D]
			e = columns_map[E]
			f = columns_map[F]
		elseif not H then
			a = columns_map[A]
			b = columns_map[B]
			c = columns_map[C]
			d = columns_map[D]
			e = columns_map[E]
			f = columns_map[F]
			g = columns_map[G]
		else
			a = columns_map[A]
			b = columns_map[B]
			c = columns_map[C]
			d = columns_map[D]
			e = columns_map[E]
			f = columns_map[F]
			g = columns_map[G]
			h = columns_map[H]
		end

		return world_query_iter_next
	end

	if not B then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns_map = archetype.columns_map
				a = columns_map[A]
			end

			local row = i
			i -= 1

			return entity, a[row]
		end
	elseif not C then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns_map = archetype.columns_map
				a = columns_map[A]
				b = columns_map[B]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row]
		end
	elseif not D then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns_map = archetype.columns_map
				a = columns_map[A]
				b = columns_map[B]
				c = columns_map[C]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row]
		end
	elseif not E then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns_map = archetype.columns_map
				a = columns_map[A]
				b = columns_map[B]
				c = columns_map[C]
				d = columns_map[D]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row]
		end
	elseif not F then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns_map = archetype.columns_map
				a = columns_map[A]
				b = columns_map[B]
				c = columns_map[C]
				d = columns_map[D]
				e = columns_map[E]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row], e[row]
		end
	elseif not G then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns_map = archetype.columns_map
				a = columns_map[A]
				b = columns_map[B]
				c = columns_map[C]
				d = columns_map[D]
				e = columns_map[E]
				f = columns_map[F]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row], e[row], f[row]
		end
	elseif not H then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns_map = archetype.columns_map
				a = columns_map[A]
				b = columns_map[B]
				c = columns_map[C]
				d = columns_map[D]
				e = columns_map[E]
				f = columns_map[F]
				g = columns_map[G]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row], e[row], f[row], g[row]
		end
	elseif not I then
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns_map = archetype.columns_map
				a = columns_map[A]
				b = columns_map[B]
				c = columns_map[C]
				d = columns_map[D]
				e = columns_map[E]
				f = columns_map[F]
				g = columns_map[G]
				h = columns_map[H]
			end

			local row = i
			i -= 1

			return entity, a[row], b[row], c[row], d[row], e[row], f[row], g[row], h[row]
		end
	else
		local output = {}
		local ids_len = #ids
		function world_query_iter_next(): any
			local entity = entities[i]
			while entity == nil do
				lastArchetype += 1
				archetype = compatible_archetypes[lastArchetype]
				if not archetype then
					return nil
				end

				entities = archetype.entities
				i = #entities
				if i == 0 then
					continue
				end
				entity = entities[i]
				columns_map = archetype.columns_map
				a = columns_map[A]
				b = columns_map[B]
				c = columns_map[C]
				d = columns_map[D]
				e = columns_map[E]
				f = columns_map[F]
				g = columns_map[G]
				h = columns_map[H]
			end

			local row = i
			i -= 1

			for i = 9, ids_len do
				output[i - 8] = columns_map[i][row]
			end

			return entity, a[row], b[row], c[row], d[row], e[row], f[row], g[row], unpack(output)
		end
	end

	local cached_query = query :: any
	cached_query.archetypes = query_archetypes
	cached_query.__iter = cached_query_iter
	cached_query.iter = cached_query_iter
	setmetatable(cached_query, cached_query)
	return cached_query
end

local Query = {}
Query.__index = Query
Query.__iter = query_iter
Query.iter = query_iter_init
Query.without = query_without
Query.with = query_with
Query.archetypes = query_archetypes
Query.cached = query_cached

local function world_query(world: World, ...)
	local compatible_archetypes = {}
	local length = 0

	local ids = { ... }

	local archetypes = world.archetypes

	local idr: ComponentRecord?
	local component_index = world.component_index

	local q = setmetatable({
		ids = ids,
		compatible_archetypes = compatible_archetypes,
		world = world,
	}, Query)

	for _, id in ids do
		local map = component_index[id]
		if not map then
			return q
		end

		if idr == nil or (map.size :: number) < (idr.size :: number) then
			idr = map
		end
	end

	if idr == nil then
		return q
	end

	for archetype_id in idr.records do
		local compatibleArchetype = archetypes[archetype_id]
		if #compatibleArchetype.entities == 0 then
			continue
		end
		local columns_map = compatibleArchetype.columns_map

		local skip = false

		for i, id in ids do
			local column = columns_map[id]
			if not column then
				skip = true
				break
			end
		end

		if skip then
			continue
		end

		length += 1
		compatible_archetypes[length] = compatibleArchetype
	end

	return q
end

local function world_each<a>(world: World, id: Id<a>): () -> Entity
	local idr = world.component_index[id]
	if not idr then
		return NOOP :: () -> Entity
	end

	local records = idr.records
	local archetypes = world.archetypes
	local archetype_id = next(records, nil) :: number
	local archetype = archetypes[archetype_id]
	if not archetype then
		return NOOP :: () -> Entity
	end

	local entities = archetype.entities
	local row = #entities

	return function(): any
		local entity = entities[row]
		while not entity do
			archetype_id = next(records, archetype_id) :: number
			if not archetype_id then
				return
			end
			archetype = archetypes[archetype_id]
			entities = archetype.entities
			row = #entities
			entity = entities[row]
		end
		row -= 1
		return entity
	end
end

local function world_children<a>(world: World, parent: Id<a>)
	return world_each(world, ECS_PAIR(EcsChildOf, parent::number))
end

local function ecs_bulk_insert(world: World, entity: Entity, ids: { Entity }, values: { any })
	local entity_index = world.entity_index
	local r = entity_index_try_get(entity_index, entity)
	if not r then
		return
	end
	local from = r.archetype
	local component_index = world.component_index
	if not from then
		local dst_types = ids
		local to = archetype_ensure(world, dst_types)
		new_entity(entity, r, to)
		local row = r.row
		local columns_map = to.columns_map
		for i, id in ids do
			local value = values[i]
			local cdr = component_index[id]

			local on_add = cdr.hooks.on_add
			if value then
				columns_map[id][row] = value
				if on_add then
					on_add(entity, id, value :: any)
				end
			else
				if on_add then
					on_add(entity, id)
				end
			end
		end
		return
	end

	local dst_types = table.clone(from.types)

	local emplaced: { [number]: boolean } = {}

	for i, id in ids do
	    local at = find_insert(dst_types :: { number }, id :: number)
	    if at == -1 then
			emplaced[i] = true
			continue
	    end

		emplaced[i] = false

	    table.insert(dst_types, at, id)
	end

	local to = archetype_ensure(world, dst_types)
	local columns_map = to.columns_map

	if from ~= to then
		entity_move(entity_index, entity, r, to)
	end
	local row = r.row

	for i, set in emplaced do
		local id = ids[i]
		local idr = component_index[id]

		local value = values[i] :: any

		local on_add = idr.hooks.on_add

		if value ~= nil then
			columns_map[id][row] = value
			local on_change = idr.hooks.on_change
			local hook = if set then on_change else on_add
			if hook then
				hook(entity, id, value :: any)
			end
		elseif on_add then
			on_add(entity, id)
		end
	end
end

local function ecs_bulk_remove(world: World, entity: Entity, ids: { Entity })
	local entity_index = world.entity_index
	local r = entity_index_try_get(entity_index, entity)
	if not r then
		return
	end
	local from = r.archetype
	local component_index = world.component_index
	if not from then
		return
	end

	local remove: { [Entity]: boolean } = {}

	local columns_map = from.columns_map

	for i, id in ids do
		if not columns_map[id] then
			continue
		end

	    remove[id] = true
		local idr = component_index[id]

		local on_remove = idr.hooks.on_remove
		if on_remove then
			on_remove(entity, id)
		end
	end

	local to = r.archetype
	if from ~= to then
		from = to
	end

	local dst_types = table.clone(from.types) :: { Entity }

	for id in remove do
		local at = table.find(dst_types, id)
		table.remove(dst_types, at)
	end

	to = archetype_ensure(world, dst_types)
	if from ~= to then
		entity_move(entity_index, entity, r, to)
	end
end

local function world_new()
	local eindex_dense_array = {} :: { Entity }
	local eindex_sparse_array = {} :: { Record }
	local eindex_alive_count = 0
	local eindex_max_id = 0

	local entity_index = {
		dense_array = eindex_dense_array,
		sparse_array = eindex_sparse_array,
		alive_count = eindex_alive_count,
		max_id = eindex_max_id,
	} :: EntityIndex

	local component_index = {} :: ComponentIndex

	local archetype_index = {} :: { [string]: Archetype }
	local archetypes = {} :: Archetypes
	local archetype_edges = {} :: { [number]: { [Id]: Archetype } }

	local observable = {}

	local world = {
		archetype_edges = archetype_edges,

		component_index = component_index,
		entity_index = entity_index,
		ROOT_ARCHETYPE = nil :: any,

		archetypes = archetypes,
		archetype_index = archetype_index,
		max_archetype_id = 0,
		max_component_id = ecs_max_component_id,

		observable = observable,
	} :: World


	local ROOT_ARCHETYPE = archetype_create(world, {}, "")
	world.ROOT_ARCHETYPE = ROOT_ARCHETYPE

	local function inner_entity_index_try_get_any(entity: number): Record?
		local r = eindex_sparse_array[ECS_ENTITY_T_LO(entity)]

		if not r or r.dense == 0 then
			return nil
		end

		return r
	end

	-- local function inner_entity_index_try_get(entity: number): Record?
	-- 	local r = inner_entity_index_try_get_any(entity)
	-- 	if r then
	-- 		local r_dense = r.dense
	-- 		if r_dense > entity_index.alive_count then
	-- 			return nil
	-- 		end
	-- 		if eindex_dense_array[r_dense] ~= entity then
	-- 			return nil
	-- 		end
	-- 	end
	-- 	return r
	-- end

	local function inner_entity_index_try_get_unsafe(entity: number): Record?
		local r = inner_entity_index_try_get_any(entity)
		if r then
			local r_dense = r.dense
			-- if r_dense > entity_index.alive_count then
			-- 	return nil
			-- end
			if eindex_dense_array[r_dense] ~= entity then
				return nil
			end
		end
		return r
	end

	local function inner_world_add<T, a>(
		world: World,
		entity: Entity<T>,
		id: Id<a>
	): ()
		local entity_index = world.entity_index
		local record = inner_entity_index_try_get_unsafe(entity :: number)
		if not record then
			return
		end

		local from = record.archetype
		local to = archetype_traverse_add(world, id, from)
		if from == to then
			return
		end
		if from then
			entity_move(entity_index, entity, record, to)
		else
			if #to.types > 0 then
				new_entity(entity, record, to)
			end
		end

		local idr = world.component_index[id]
		local on_add = idr.hooks.on_add

		if on_add then
			on_add(entity, id)
		end
	end

	local function inner_world_get(world: World, entity: Entity,
		a: Id, b: Id?, c: Id?, d: Id?, e: Id?): ...any
		local record = inner_entity_index_try_get_unsafe(entity::number)
		if not record then
			return nil
		end

		local archetype = record.archetype
		if not archetype then
			return nil
		end

		local columns_map = archetype.columns_map
		local row = record.row

		local va = fetch(a, columns_map, row)

		if not b then
			return va
		elseif not c then
			return va, fetch(b, columns_map, row)
		elseif not d then
			return va, fetch(b, columns_map, row), fetch(c, columns_map, row)
		elseif not e then
			return va, fetch(b, columns_map, row), fetch(c, columns_map, row), fetch(d, columns_map, row)
		else
			error("args exceeded")
		end
	end

	local function inner_world_has(world: World, entity: i53,
		a: i53, b: i53?, c: i53?, d: i53?, e: i53?): boolean

		local record = inner_entity_index_try_get_unsafe(entity)
		if not record then
			return false
		end

		local archetype = record.archetype
		if not archetype then
			return false
		end

		local columns_map = archetype.columns_map

		return columns_map[a] ~= nil and
			(b == nil or columns_map[b] ~= nil) and
			(c == nil or columns_map[c] ~= nil) and
			(d == nil or columns_map[d] ~= nil) and
			(e == nil or error("args exceeded"))
	end

	local function inner_world_target<T, a>(world: World, entity: Entity<T>, relation: Id<a>, index: number?): Entity?
		local record = inner_entity_index_try_get_unsafe(entity :: number)
		if not record then
			return nil
		end

		local archetype = record.archetype
		if not archetype then
			return nil
		end

		local r = ECS_PAIR(relation::number, EcsWildcard)
		local idr = world.component_index[r]

		if not idr then
			return nil
		end

		local archetype_id = archetype.id
		local count = idr.counts[archetype_id]
		if not count then
			return nil
		end

		local nth = index or 0

		if nth >= count then
			nth = nth + count + 1
		end

		nth = archetype.types[nth + idr.records[archetype_id]]

		if not nth then
			return nil
		end

		return entity_index_get_alive(world.entity_index,
		    ECS_PAIR_SECOND(nth :: number))
	end

	local function inner_world_parent<T>(world: World, entity: Entity<T>): Entity?
		return inner_world_target(world, entity, EcsChildOf, 0)
	end

	local function inner_archetype_traverse_add(id: Id, from: Archetype): Archetype
		from = from or ROOT_ARCHETYPE
		if from.columns_map[id] then
			return from
		end
		local edges = archetype_edges
		local edge = edges[from.id]

		local to = edge[id] :: Archetype
		if not to then
			to = find_archetype_with(world, id, from)
			edge[id] = to
			edges[to.id][id] = from
		end

		return to
	end

	local function inner_world_set<T, a>(world: World, entity: Entity<T>, id: Id<a>, data: a): ()
		local record = inner_entity_index_try_get_unsafe(entity :: number)
		if not record then
			return
		end

		local from: Archetype = record.archetype
		local to: Archetype = inner_archetype_traverse_add(id, from)
		local idr = component_index[id]
		local idr_hooks = idr.hooks

		if from == to then
			local column = to.columns_map[id]
			column[record.row] = data

			-- If the archetypes are the same it can avoid moving the entity
			-- and just set the data directly.
			local on_change = idr_hooks.on_change
			if on_change then
				on_change(entity, id, data)
			end

			return
		end

		if from then
			-- If there was a previous archetype, then the entity needs to move the archetype
			entity_move(entity_index, entity, record, to)
		else
			new_entity(entity, record, to)
		end
		local column = to.columns_map[id]
		column[record.row] = data

		local on_add = idr_hooks.on_add
		if on_add then
			on_add(entity, id, data)
		end
	end

	local function inner_world_entity<T>(world: World, entity: Entity<T>?): Entity<T>
		if entity then
			local index = ECS_ID(entity :: number)
			local alive_count = entity_index.alive_count
			local r = eindex_sparse_array[index]
			if r then
				local dense = r.dense

				if not dense or r.dense == 0 then
					r.dense = index
					dense = index
				end

				local any = eindex_dense_array[dense]
				if dense <= alive_count then
					if any ~= entity then
						error("Entity ID is already in use with a different generation")
					else
						return entity
					end
				end

				local e_swap = eindex_dense_array[dense]
				local r_swap = inner_entity_index_try_get_any(e_swap :: number) :: Record
				alive_count += 1
				entity_index.alive_count = alive_count
				r_swap.dense = dense
				r.dense = alive_count
				eindex_dense_array[dense] = e_swap
				eindex_dense_array[alive_count] = entity

				return entity
			else
				for i = eindex_max_id + 1, index do
					eindex_sparse_array[i]= { dense = i } :: Record
					eindex_dense_array[i] = i
				end
				entity_index.max_id = index

				local e_swap = eindex_dense_array[alive_count]
				local r_swap = eindex_sparse_array[alive_count]
				r_swap.dense = index

				alive_count += 1
				entity_index.alive_count = alive_count

				r = eindex_sparse_array[index]

				r.dense = alive_count

				eindex_sparse_array[index] = r

				eindex_dense_array[index] = e_swap
				eindex_dense_array[alive_count] = entity

				return entity
			end
		end
		return entity_index_new_id(entity_index)
	end

	local function inner_world_remove<T, a>(world: World, entity: Entity<T>, id: Id<a>)
		local record = inner_entity_index_try_get_unsafe(entity :: number)
		if not record then
			return
		end
		local from = record.archetype

		if not from then
			return
		end

		if from.columns_map[id] then
			local idr = world.component_index[id]
			local on_remove = idr.hooks.on_remove
			if on_remove then
				on_remove(entity, id)
			end

			local to = archetype_traverse_remove(world, id, record.archetype)

			entity_move(entity_index, entity, record, to)
		end
	end

	local function inner_world_clear<T>(world: World, entity: Entity<T>)
		local tgt = ECS_PAIR(EcsWildcard, entity::number)
		local idr_t = component_index[tgt]
		local idr = component_index[entity]
		local rel = ECS_PAIR(entity::number, EcsWildcard)
		local idr_r = component_index[rel]

		if idr then
			local count = 0
			local queue = {}
			for archetype_id in idr.records do
				local idr_archetype = archetypes[archetype_id]
				local entities = idr_archetype.entities
				local n = #entities
				table.move(entities, 1, n, count + 1, queue)
				count += n
			end
			for _, e in queue do
				inner_world_remove(world, e, entity)
			end
		end

		if idr_t then
			local queue: { i53 }
			local ids: Map<i53, boolean>

			local count = 0
			local archetype_ids = idr_t.records
			for archetype_id in archetype_ids do
				local idr_t_archetype = archetypes[archetype_id]
				local idr_t_types = idr_t_archetype.types
				local entities = idr_t_archetype.entities
				local removal_queued = false

				for _, id in idr_t_types do
					if not ECS_IS_PAIR(id::number) then
						continue
					end
					local object = entity_index_get_alive(
					    entity_index, ECS_PAIR_SECOND(id::number))
					if object ~= entity then
						continue
					end
					if not ids then
						ids = {} :: { [i53]: boolean }
					end
					ids[id] = true
					removal_queued = true
				end

				if not removal_queued then
					continue
				end

				if not queue then
					queue = {} :: { i53 }
				end

				local n = #entities
				table.move(entities, 1, n, count + 1, queue)
				count += n
			end

			for id in ids do
				for _, child in queue do
					inner_world_remove(world, child, id)
				end
			end
		end

		if idr_r then
			local count = 0
			local archetype_ids = idr_r.records
			local ids = {}
			local queue = {}
			local records = idr_r.records
			local counts = idr_r.counts
			for archetype_id in archetype_ids do
				local idr_r_archetype = archetypes[archetype_id]
				local entities = idr_r_archetype.entities
				local tr = records[archetype_id]
				local tr_count = counts[archetype_id]
				local types = idr_r_archetype.types
				for i = tr, tr + tr_count - 1 do
					ids[types[i]] = true
				end
				local n = #entities
				table.move(entities, 1, n, count + 1, queue)
				count += n
			end

			for _, e in queue do
				for id in ids do
					inner_world_remove(world, e, id)
				end
			end
		end

	end

	local function inner_world_delete<T>(world: World, entity: Entity<T>)
		local entity_index = world.entity_index
		local record = inner_entity_index_try_get_unsafe(entity::number)
		if not record then
			return
		end

		local archetype = record.archetype
		local row = record.row

		if archetype then
			-- In the future should have a destruct mode for
			-- deleting archetypes themselves. Maybe requires recycling
			archetype_delete(world, archetype, row)
		end

		local component_index = world.component_index
		local archetypes = world.archetypes
		local tgt = ECS_PAIR(EcsWildcard, entity::number)
		local rel = ECS_PAIR(entity::number, EcsWildcard)

		local idr_t = component_index[tgt]
		local idr = component_index[entity::number]
		local idr_r = component_index[rel]

		if idr then
			local flags = idr.flags
			if bit32.btest(flags, ECS_ID_DELETE) then
				for archetype_id in idr.records do
					local idr_archetype = archetypes[archetype_id]

					local entities = idr_archetype.entities
					local n = #entities
					for i = n, 1, -1 do
						inner_world_delete(world, entities[i])
					end

					archetype_destroy(world, idr_archetype)
				end
			else
				local on_remove = idr.hooks.on_remove
				if on_remove then
					for archetype_id in idr.records do
						local idr_archetype = archetypes[archetype_id]
						local to = archetype_traverse_remove(world, entity, idr_archetype)
						local entities = idr_archetype.entities
						local n = #entities
						for i = n, 1, -1 do
							local e = entities[i]
							on_remove(e, entity)
							local r = eindex_sparse_array[ECS_ID(e :: number)]
							local from = r.archetype
							if from ~= idr_archetype then
								-- unfortunately the on_remove hook allows a window where `e` can have changed archetype
								-- this is hypothetically not that expensive of an operation anyways
								to = archetype_traverse_remove(world, entity, from)
							end
							entity_move(entity_index, e, r, to)
						end

						archetype_destroy(world, idr_archetype)
					end
				else
					for archetype_id in idr.records do
						local idr_archetype = archetypes[archetype_id]
						local to = archetype_traverse_remove(world, entity, idr_archetype)
						local entities = idr_archetype.entities
						local n = #entities
						for i = n, 1, -1 do
							local e = entities[i]
							entity_move(entity_index, e, eindex_sparse_array[ECS_ID(e :: number)], to)
						end

						archetype_destroy(world, idr_archetype)
					end
				end
			end
		end

		if idr_t then
			local children: { i53 }
			local ids: Map<i53, boolean>

			local count = 0
			local archetype_ids = idr_t.records
			for archetype_id in archetype_ids do
				local idr_t_archetype = archetypes[archetype_id]
				local idr_t_types = idr_t_archetype.types
				local entities = idr_t_archetype.entities
				local removal_queued = false

				for _, id in idr_t_types do
					if not ECS_IS_PAIR(id::number) then
						continue
					end
					local object = entity_index_get_alive(
					    entity_index, ECS_PAIR_SECOND(id::number))
					if object ~= entity then
						continue
					end
					local id_record = component_index[id]
					local flags = id_record.flags
					local flags_delete_mask = bit32.btest(flags, ECS_ID_DELETE)
					if flags_delete_mask then
						for i = #entities, 1, -1 do
							local child = entities[i]
							inner_world_delete(world, child)
						end
						break
					else
						if not ids then
							ids = {} :: { [i53]: boolean }
						end
						ids[id] = true
						removal_queued = true
					end
				end

				if not removal_queued then
					continue
				end
				if not children then
					children = {} :: { i53 }
				end
				local n = #entities
				table.move(entities, 1, n, count + 1, children)
				count += n
			end

			if ids then
				for _, child in children do
					for id in ids do
						inner_world_remove(world, child, id)
					end
				end
			end

			for archetype_id in archetype_ids do
				archetype_destroy(world, archetypes[archetype_id])
			end
		end

		if idr_r then
			local archetype_ids = idr_r.records
			local flags = idr_r.flags
			if bit32.btest(flags, ECS_ID_DELETE) then
				for archetype_id in archetype_ids do
					local idr_r_archetype = archetypes[archetype_id]
					local entities = idr_r_archetype.entities
					local n = #entities
					for i = n, 1, -1 do
						inner_world_delete(world, entities[i])
					end
					archetype_destroy(world, idr_r_archetype)
				end
			else
				local children = {}
				local count = 0
				local ids = {}
				local counts = idr_r.counts
				local records = idr_r.records
				for archetype_id in archetype_ids do
					local idr_r_archetype = archetypes[archetype_id]
					local entities = idr_r_archetype.entities
					local tr = records[archetype_id]
					local tr_count = counts[archetype_id]
					local types = idr_r_archetype.types
					for i = tr, tr + tr_count - 1 do
						ids[types[i]] = true
					end

					local n = #entities
					table.move(entities, 1, n, count + 1, children)
					count += n
				end
				for _, child in children do
					for id in ids do
						inner_world_remove(world, child, id)
					end
				end

				for archetype_id in archetype_ids do
					archetype_destroy(world, archetypes[archetype_id])
				end
			end
		end

		local dense_array = entity_index.dense_array
		local dense = record.dense
		local i_swap = entity_index.alive_count
		entity_index.alive_count = i_swap - 1

		local e_swap = dense_array[i_swap]
		local r_swap = inner_entity_index_try_get_any(e_swap :: number) :: Record

		r_swap.dense = dense
		record.archetype = nil :: any
		record.row = nil :: any
		record.dense = i_swap

		dense_array[dense] = e_swap
		dense_array[i_swap] = ECS_GENERATION_INC(entity :: number)
	end

	local function inner_world_exists<T>(world: World, entity: Entity<T>): boolean
		return inner_entity_index_try_get_any(entity :: number) ~= nil
	end

	local function inner_world_contains<T>(world: World, entity: Entity<T>): boolean
		return entity_index_is_alive(world.entity_index, entity)
	end

	local function inner_world_cleanup(world: World)
		for _, archetype in archetypes do
			if #archetype.entities == 0 then
				archetype_destroy(world, archetype)
			end
		end

		local new_archetypes = {}
		local new_archetype_map = {}

		for index, archetype in archetypes do
			new_archetypes[index] = archetype
			new_archetype_map[archetype.type] = archetype
		end

		archetypes = new_archetypes
		archetype_index = new_archetype_map

		world.archetypes = new_archetypes
		world.archetype_index = new_archetype_map
	end

	world.entity = inner_world_entity
	world.query = world_query :: any
	world.remove = inner_world_remove
	world.clear = inner_world_clear
	world.delete = inner_world_delete
	world.component = world_component
	world.add = inner_world_add
	world.set = inner_world_set
	world.get = inner_world_get :: any
	world.has = inner_world_has :: any
	world.target = inner_world_target
	world.parent = inner_world_parent
	world.contains = inner_world_contains
	world.exists = inner_world_exists
	world.cleanup = inner_world_cleanup
	world.each = world_each
	world.children = world_children
	world.range = world_range

	for i = 1, HI_COMPONENT_ID do
		local e = entity_index_new_id(entity_index)
		inner_world_add(world, e, EcsComponent)
	end

	for i = HI_COMPONENT_ID + 1, EcsRest do
		-- Initialize built-in components
		entity_index_new_id(entity_index)
	end

	inner_world_add(world, EcsName, EcsComponent)
	inner_world_add(world, EcsOnChange, EcsComponent)
	inner_world_add(world, EcsOnAdd, EcsComponent)
	inner_world_add(world, EcsOnRemove, EcsComponent)
	inner_world_add(world, EcsWildcard, EcsComponent)
	inner_world_add(world, EcsRest, EcsComponent)

	inner_world_set(world, EcsOnAdd, EcsName, "jecs.OnAdd")
	inner_world_set(world, EcsOnRemove, EcsName, "jecs.OnRemove")
	inner_world_set(world, EcsOnChange, EcsName, "jecs.OnChange")
	inner_world_set(world, EcsWildcard, EcsName, "jecs.Wildcard")
	inner_world_set(world, EcsChildOf, EcsName, "jecs.ChildOf")
	inner_world_set(world, EcsComponent, EcsName, "jecs.Component")
	inner_world_set(world, EcsOnDelete, EcsName, "jecs.OnDelete")
	inner_world_set(world, EcsOnDeleteTarget, EcsName, "jecs.OnDeleteTarget")
	inner_world_set(world, EcsDelete, EcsName, "jecs.Delete")
	inner_world_set(world, EcsRemove, EcsName, "jecs.Remove")
	inner_world_set(world, EcsName, EcsName, "jecs.Name")
	inner_world_set(world, EcsRest, EcsRest, "jecs.Rest")

	inner_world_add(world, EcsChildOf, ECS_PAIR(EcsOnDeleteTarget, EcsDelete))

	for i = EcsRest + 1, ecs_max_tag_id do
		entity_index_new_id(entity_index)
	end

	for i, bundle in ecs_metadata do
		for ty, value in bundle do
			if value == NULL then
				inner_world_add(world, i, ty)
			else
				inner_world_set(world, i, ty, value)
			end
		end
	end

	return world
end

-- type function ecs_id_t(entity)
-- 	local ty = entity:components()[2]
-- 	local __T = ty:readproperty(types.singleton("__T"))
-- 	if not __T then
-- 		return ty:readproperty(types.singleton("__jecs_pair_value"))
-- 	end
-- 	return __T
-- end

-- type function ecs_pair_t(first, second)
-- 	if ecs_id_t(first):is("nil") then
-- 		return second
-- 	else
-- 		return first
-- 	end
-- end
--

local function ecs_is_tag(world: World, entity: Entity): boolean
	local idr = world.component_index[entity]
	if idr then
		return bit32.btest(idr.flags, ECS_ID_IS_TAG)
	end
	return not world_has_one_inline(world, entity, EcsComponent)
end

return {
	world = world_new :: () -> World,
	component = (ECS_COMPONENT :: any) :: <T>() -> Entity<T>,
	tag = (ECS_TAG :: any) :: <T>() -> Entity<T>,
	meta = (ECS_META :: any) :: <T>(id: Entity, id: Id<T>, value: T) -> Entity<T>,
	is_tag = (ecs_is_tag :: any) :: <T>(World, Id<T>) -> boolean,

    OnAdd = (EcsOnAdd :: any) :: Entity<<T>(entity: Entity, id: Id<T>, data: T) -> ()>,
	OnRemove = (EcsOnRemove :: any) :: Entity<(entity: Entity, id: Id) -> ()>,
	OnChange = (EcsOnChange :: any) :: Entity<<T>(entity: Entity, id: Id<T>, data: T) -> ()>,
	ChildOf = (EcsChildOf :: any) :: Entity,
	Component = (EcsComponent :: any) :: Entity,
	Wildcard = (EcsWildcard :: any) :: Entity,
	w = (EcsWildcard :: any) :: Entity,
	OnDelete = (EcsOnDelete :: any) :: Entity,
	OnDeleteTarget = (EcsOnDeleteTarget :: any) :: Entity,
	Delete = (EcsDelete :: any) :: Entity,
	Remove = (EcsRemove :: any) :: Entity,
	Name = (EcsName :: any) :: Entity<string>,
	Exclusive = EcsExclusive :: Entity,
	Rest = (EcsRest :: any) :: Entity,

	pair = (ECS_PAIR :: any) :: <P, O>(first: Id<P>, second: Id<O>) -> Pair<P, O>,

	-- Inwards facing API for testing
	ECS_ID = ECS_ENTITY_T_LO,
	ECS_GENERATION_INC = ECS_GENERATION_INC,
	ECS_GENERATION = ECS_GENERATION,
	ECS_ID_IS_WILDCARD = ECS_ID_IS_WILDCARD,
	ECS_ID_DELETE = ECS_ID_DELETE,
	ECS_META_RESET = ECS_META_RESET,

	IS_PAIR = (ECS_IS_PAIR :: any) :: <P, O>(pair: Pair<P, O>) -> boolean,
	ECS_PAIR_FIRST = ECS_PAIR_FIRST :: <P, O>(pair: Pair<P, O>) -> Id<P>,
	ECS_PAIR_SECOND = ECS_PAIR_SECOND :: <P, O>(pair: Pair<P, O>) -> Id<O>,
	pair_first = (ecs_pair_first :: any) :: <P, O>(world: World, pair: Pair<P, O>) -> Id<P>,
	pair_second = (ecs_pair_second :: any) :: <P, O>(world: World, pair: Pair<P, O>) -> Id<O>,
	entity_index_get_alive = entity_index_get_alive,

	archetype_append_to_records = archetype_append_to_records,
	id_record_ensure = id_record_ensure,
	component_record = id_record_get,
	archetype_create = archetype_create,
	archetype_ensure = archetype_ensure,
	find_insert = find_insert,
	find_archetype_with = find_archetype_with,
	find_archetype_without = find_archetype_without,
	create_edge_for_remove = create_edge_for_remove,
	archetype_traverse_add = archetype_traverse_add,
	archetype_traverse_remove = archetype_traverse_remove,
	bulk_insert = ecs_bulk_insert,
	bulk_remove = ecs_bulk_remove,

	entity_move = entity_move,

	entity_index_try_get = entity_index_try_get,
	entity_index_try_get_any = entity_index_try_get_any,
	entity_index_is_alive = entity_index_is_alive,
	entity_index_new_id = entity_index_new_id,

	query_iter = query_iter,
	query_iter_init = query_iter_init,
	query_with = query_with,
	query_without = query_without,
	query_archetypes = query_archetypes,
	query_match = query_match,

	find_observers = find_observers,
}
