/**
 * A unique identifier in the world, entity.
 * The generic type T defines the data type when this entity is used as a component
 */
export type Entity<T = undefined | unknown> = number & { __jecs_value: T };

/**
 * An entity with no associated data when used as a component
 */
export type Tag = Entity<undefined>;

/**
 * A pair of entities
 * P is the type of the predicate, O is the type of the object, and V is the type of the value (defaults to P)
 */
export type Pair<P = undefined, O = undefined, V = P> = number & {
	__jecs_pair_pred: P;
	__jecs_pair_obj: O;
	__jecs_pair_value: V;
};

/**
 * Either an Entity or a Pair
 */
export type Id<T = unknown> = Entity<T> | Pair<unknown, unknown, T>;

type InferComponent<E> = E extends Id<infer T> ? T : never;
type FlattenTuple<T extends any[]> = T extends [infer U] ? U : LuaTuple<T>;
type Nullable<T extends unknown[]> = { [K in keyof T]: T[K] | undefined };
type InferComponents<A extends Id[]> = {
	[K in keyof A]: InferComponent<A[K]>;
};
type TupleForWorldGet = [Id] | [Id, Id] | [Id, Id, Id] | [Id, Id, Id, Id];

type Iter<T extends unknown[]> = IterableFunction<LuaTuple<[Entity, ...T]>>;

export type Query<T extends unknown[]> = {
	/**
	 * Returns an iterator that returns a tuple of an entity and queried components
	 */
	iter(): Iter<T>;

	/**
	 * Modifies the query to include specified components
	 * @param components The components to include
	 * @returns Modified Query
	 */
	with(...components: Id[]): Query<T>;

	/**
	 * Modifies the Query to exclude specified components
	 * @param components The components to exclude
	 * @returns Modified Query
	 */
	without(...components: Id[]): Query<T>;
} & Iter<T>;

export class World {
	/**
	 * Creates a new World
	 */
	constructor();

	/**
	 * Creates a new entity
	 * @returns Entity
	 */
	entity(): Tag;

	/**
	 * Creates a new entity located in the first 256 ids.
	 * These should be used for static components for fast access.
	 * @returns Entity<T>
	 */
	component<T = unknown>(): Entity<T>;

	/**
	 * Gets the target of a relationship. For example, when a user calls
	 * `world.target(entity, ChildOf(parent))`, you will obtain the parent entity.
	 * @param entity Entity
	 * @param relation The Relationship
	 * @returns The Parent Entity if it exists
	 */
	target(entity: Entity, relation: Entity): Entity | undefined;

	/**
	 * Gets the target of a relationship at a specific index.
	 * For example, when a user calls `world.target(entity, ChildOf(parent), 0)`,
	 * you will obtain the parent entity.
	 * @param entity Entity
	 * @param relation The Relationship
	 * @param index Target index
	 * @returns The Parent Entity if it exists
	 */
	target(entity: Entity, relation: Entity, index: number): Entity | undefined;

	/**
	 * Clears an entity from the world
	 * @param entity Entity to be cleared
	 */
	clear(entity: Entity): void;

	/**
	 * Deletes an entity and all its related components and relationships
	 * @param entity Entity to be destroyed
	 */
	delete(entity: Entity): void;

	/**
	 * Adds a component to the entity with no value
	 * @param entity Target Entity
	 * @param component Component
	 */
	add(entity: Entity, component: Id): void;

	/**
	 * Assigns a value to a component on the given entity
	 * @param entity Target Entity
	 * @param component Target Component
	 * @param value Component Value
	 */
	set<E extends Id<unknown>>(entity: Entity, component: E, value: InferComponent<E>): void;

	/**
	 * Removes a component from the given entity
	 * @param entity Target Entity
	 * @param component Target Component
	 */
	remove(entity: Entity, component: Id): void;

	/**
	 * Retrieves the values of specified components for an entity.
	 * Some values may not exist when called.
	 * A maximum of 4 components are allowed at a time.
	 * @param id Target Entity
	 * @param components Target Components
	 * @returns Data associated with target components if it exists.
	 */
	get<T extends TupleForWorldGet>(id: Entity, ...components: T): FlattenTuple<Nullable<InferComponents<T>>>;

	/**
	 * Returns whether the entity has the specified components.
	 * A maximum of 4 components are allowed at a time.
	 * @param entity Target Entity
	 * @param components Target Components
	 * @returns If the entity contains the components
	 */
	has(entity: Entity, ...components: Id[]): boolean;

	/**
	 * Checks if an entity exists in the world
	 * @param entity Entity to check
	 * @returns Whether the entity exists in the world
	 */
	contains(entity: Entity): boolean;

	/**
	 * Get parent (target of ChildOf relationship) for entity.
	 * If there is no ChildOf relationship pair, it will return undefined.
	 * @param entity Target Entity
	 * @returns Parent Entity or undefined
	 */
	parent(entity: Entity): Entity | undefined;

	/**
	 * Searches the world for entities that match a given query
	 * @param components Queried Components
	 * @returns Query
	 */
	query<T extends Id[]>(...components: T): Query<InferComponents<T>>;
}

/**
 * Creates a composite key (pair)
 * @param pred The first entity (predicate)
 * @param obj The second entity (object)
 * @returns The composite key (pair)
 */
export function pair<P, O, V = P>(pred: Entity<P>, obj: Entity<O>): Pair<P, O, V>;

/**
 * Checks if the entity is a composite key (pair)
 * @param value The entity to check
 * @returns If the entity is a pair
 */
export function IS_PAIR(value: Id): value is Pair;

/**
 * Gets the first entity (predicate) of a pair
 * @param pair The pair to get the first entity from
 * @returns The first entity (predicate) of the pair
 */
export function pair_first<P, O, V = P>(pair: Pair<P, O, V>): Entity<P>;

/**
 * Gets the second entity (object) of a pair
 * @param pair The pair to get the second entity from
 * @returns The second entity (object) of the pair
 */
export function pair_second<P, O, V = P>(pair: Pair<P, O, V>): Entity<O>;

export const OnAdd: Entity<(e: Entity) => void>;
export const OnRemove: Entity<(e: Entity) => void>;
export const OnSet: Entity<(e: Entity, value: unknown) => void>;
export const ChildOf: Entity;
export const Wildcard: Entity;
export const w: Entity;
export const OnDelete: Entity;
export const OnDeleteTarget: Entity;
export const Delete: Entity;
export const Remove: Entity;
export const Name: Entity<string>;
export const Rest: Entity;
