type i53 = number;
type i24 = number;

type Ty = Array<i53>;

type Column = Array<unknown>;

type Archetype = {
	id: number,
	edges: {
		[key: i53]: {
			add: Archetype,
			remove: Archetype,
		},
	},
	types: Ty,
	type: string | number,
	entities: Array<number>,
	columns: Array<Column>,
	records: { [key: number]: number },
}

type ArchetypeMap = {
	cache: Array<ArchetypeRecord>,
	first: ArchetypeMap,
	second: ArchetypeMap,
	parent: ArchetypeMap,
	size: number,
}

type ArchetypeRecord = number;

export type Entity<T = unknown> = number & { __nominal_type_dont_use: T }

type EntityIndex = {
    dense: {
        [key: i24]: i53
    };
    sparse: {
        [key: i53]: Record
    }
}

type Record = {
	archetype: Archetype,
	row: number,
	dense: i24,
	componentRecord: ArchetypeMap,
}

type ExtractFromLuaTuple<T> = T extends LuaTuple<infer U> ? U : never;

type QueryShim<T extends any[]> = {
    without: (...args: ExtractFromLuaTuple<T>) => QueryShim<T>;
} & IterableFunction<T>;

interface World {
    entity(): Entity;
    component<T = unknown>(): Entity<T>;

    target(id: Entity, relation: Entity): Entity | undefined;
    delete(id: Entity): void;

    add<T>(id: Entity, component: Entity<T>): void;
    set<T>(id: Entity, component: Entity<T>, data: T): void;
    remove(id: Entity, component: Entity): void;

    get<A>(id: number, component: Entity<A>): A; // Manually typed out since there is a hard limit.
    get<A, B>(id: number, component: Entity<A>, component2: Entity<B>): LuaTuple<[A, B]>;
    get<A, B, C>(id: number, component: Entity<A>, component2: Entity<B>, component3: Entity<C>): LuaTuple<[A, B, C]>;
    get<A, B, C, D>(id: number, component: Entity<A>, component2: Entity<B>, component3: Entity<C>, component4: Entity<D>): LuaTuple<[A, B, C, D]>;
    
    query<T extends unknown[]>(...entities: T): QueryShim<LuaTuple<[...T]>>
}

interface WorldConstructor {
    new(): World
}

export const World: WorldConstructor;

export const pair: (pred: Entity, obj: Entity) => Entity;

export const OnAdd: Entity;
export const OnRemove: Entity;
export const OnSet: Entity;
export const Wildcard: Entity;
export const w: Entity;
export const REST: Entity;

export const IS_PAIR: (e: number) => boolean;
export const ECS_ID: (e: i53) => i24;
export const ECS_PAIR: (pred: i53, obj: i53) => i53;
export const ECS_GENERATION_INC: (e: i53) => i53;
export const ECS_GENERATION: (e: i53) => i53;
export const ECS_PAIR_RELATION: <T>(entityIndex: EntityIndex, e: Entity<T>) => i53;
export const ECS_PAIR_OBJECT: <T>(entityIndex: EntityIndex, e: Entity<T>) => i53;

export const getAlive: (entityIndex: EntityIndex, id: i24) => i53;