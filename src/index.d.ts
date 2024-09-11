/**
 * Represents an entity
 * The generic type T defines the data type when this entity is used as a component
 */
export type Entity<T = unknown> = number & { __T: T };

export type Pair = number;

export type Id<T = unknown> = Entity<T> | Pair;

type FlattenTuple<T extends any[]> = T extends [infer U] ? U : LuaTuple<T>;
type Nullable<T extends unknown[]> = { [K in keyof T]: T[K] | undefined };
type InferComponents<A extends Id[]> = { [K in keyof A]: A[K] extends Id<infer T> ? T : never };
type TupleForWorldGet = [Id] | [Id, Id] | [Id, Id, Id] | [Id, Id, Id, Id];

type Item<T extends unknown[]> = (this: Query<T>) => LuaTuple<[Entity, ...T]>;

export type Query<T extends unknown[]> = {
	/**
	 * Get the next result in the query. Drain must have been called beforehand or otherwise it will error.
	 */
	next: Item<T>;

	/**
	 * Resets the Iterator for a query.
	 */
	drain: (this: Query<T>) => Query<T>;

	/**
	 * Modifies the query to include specified components, but will not include the values.
	 * @param components The components to include
	 * @returns Modified Query
	 */
	with: (this: Query<T>, ...components: Id[]) => Query<T>;

	/**
	 * Modifies the Query to exclude specified components
	 * @param components The components to exclude
	 * @returns Modified Query
	 */
	without: (this: Query<T>, ...components: Id[]) => Query<T>;

	/**
	 * Modifies component data with a callback function
	 * @param fn The function to modify data
	 */
	replace: (this: Query<T>, fn: (...components: T) => FlattenTuple<T>) => void;

	/**
	 * Returns the archetypes associated with this query.
	 */
	archetypes: () => Archetype[];
} & IterableFunction<LuaTuple<[Entity, ...T]>>;

export type Archetype = {
	id: number;
	edges: { [key: number]: ArchetypeEdge };
	types: number[];
	type: string | number;
	entities: number[];
	columns: unknown[][];
	records: { [key: number]: ArchetypeRecord };
};

type ArchetypeRecord = {
	count: number;
	column: number;
};

type ArchetypeEdge = {
	add: Archetype;
	remove: Archetype;
};

export class World {
	/**
	 * Creates a new World
	 */
	constructor();

	/**
	 * Creates a new entity
	 * @returns Entity
	 */
	entity(): Entity;

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
	target(entity: Entity, relation: Entity, index: number): Entity | undefined;

	/**
	 * Clears an entity from the world.
	 * @param entity Entity to be cleared
	 */
	clear(entity: Entity): void;

	/**
	 * Deletes an entity and all its related components and relationships.
	 * @param entity Entity to be destroyed
	 */
	delete(entity: Entity): void;

	/**
	 * Adds a component to the entity with no value
	 * @param entity Target Entity
	 * @param component Component
	 */
	add<T>(entity: Entity, component: Id<T>): void;

	/**
	 * Assigns a value to a component on the given entity
	 * @param entity Target Entity
	 * @param component Target Component
	 * @param data Component Data
	 */
	set<T>(entity: Entity, component: Id<T>, data: T): void;

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
	 * Searches the world for entities that match a given query
	 * @param components Queried Components
	 * @returns Query
	 */
	query<T extends Id[]>(...components: T): Query<InferComponents<T>>;

	/**
	 * Get parent (target of ChildOf relationship) for entity.
	 * If there is no ChildOf relationship pair, it will return undefined.
	 * @param entity Target Entity
	 * @returns Parent Entity or undefined
	 */
	parent(entity: Entity): Entity | undefined;
}

/**
 * Creates a composite key.
 * @param pred The first entity
 * @param obj The second entity
 * @returns The composite key
 */
export function pair<R, T>(pred: Entity<R>, obj: Entity<T>): Pair;

/**
 * Checks if the entity is a composite key
 * @param e The entity to check
 * @returns If the entity is a pair
 */
export function IS_PAIR(e: Id): boolean;

/** Built-in Component used to find every component id */
export const Component: Entity;

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
export const Tag: Entity;
export const Name: Entity<string>;
export const Rest: Entity;
