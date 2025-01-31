/**
 * A unique identifier in the world, entity.
 * The generic type T defines the data type when this entity is used as a component
 */
export type Entity<TData = unknown> = number & {
	readonly __nominal_Entity: unique symbol;
	readonly __type_TData: TData;
};

/**
 * An entity with no associated data when used as a component
 */
export type Tag = Entity<undefined>;

/**
 * A pair of entities:
 * - `pred` is the type of the "predicate" entity.
 * - `obj` is the type of the "object" entity.
 */
export type Pair<P = unknown, O = unknown> = number & {
	readonly __nominal_Pair: unique symbol;
	readonly __pred: P;
	readonly __obj: O;
};
/**
 * An `Id` can be either a single Entity or a Pair of Entities.
 * By providing `TData`, you can specifically require an Id that yields that type.
 */
export type Id<TData = unknown> = Entity<TData> | Pair<TData, unknown> | Pair<undefined, TData>;

export type InferComponent<E> = E extends Entity<infer D>
	? D
	: E extends Pair<infer P, infer O>
		? P extends undefined
			? O
			: P
		: never;

type FlattenTuple<T extends unknown[]> = T extends [infer U] ? U : LuaTuple<T>;
type Nullable<T extends unknown[]> = { [K in keyof T]: T[K] | undefined };
type InferComponents<A extends Id[]> = { [K in keyof A]: InferComponent<A[K]> };

type ArchetypeId = number
type Column = unknown[];

type ArchetypeRecord = {
    count: number;
    column: number;
}

export type Archetype = {
    id: number;
    types: number[];
    type: string;
    entities: number[];
    columns: Column[];
    records: ArchetypeRecord[];
}

type Iter<T extends unknown[]> = IterableFunction<LuaTuple<[Entity, ...T]>>;

export type CachedQuery<T extends unknown[]> = {
	/**
	 * Returns an iterator that produces a tuple of [Entity, ...queriedComponents].
	 */
	iter(): Iter<T>;

	/**
	 * Returns the matched archetypes of the query
	 * @returns An array of archetypes of the query
	 */
	archetypes(): Archetype[];
} & Iter<T>;

export type Query<T extends unknown[]> = {
	/**
	 * Returns an iterator that produces a tuple of [Entity, ...queriedComponents].
	 */
	iter(): Iter<T>;

	/**
	 * Creates and returns a cached version of this query for efficient reuse.
	 * Call refinement methods (with/without) on the query before caching.
	 * @returns A cached query
	 */
	cached(): CachedQuery<T>;

	/**
	 * Modifies the query to include specified components.
	 * @param components The components to include.
	 * @returns A new Query with the inclusion applied.
	 */
	with(...components: Id[]): Query<T>;

	/**
	 * Modifies the Query to exclude specified components.
	 * @param components The components to exclude.
	 * @returns A new Query with the exclusion applied.
	 */
	without(...components: Id[]): Query<T>;

	/**
	 * Returns the matched archetypes of the query
	 * @returns An array of archetypes of the query
	 */
	archetypes(): Archetype[];
} & Iter<T>;

export class World {
	/**
	 * Creates a new World.
	 */
	constructor();

	/**
	 * Creates a new entity.
	 * @returns An entity (Tag) with no data.
	 */
	entity(): Tag;

	/**
	 * Creates a new entity in the first 256 IDs, typically used for static
	 * components that need fast access.
	 * @returns A typed Entity with `TData`.
	 */
	component<TData = unknown>(): Entity<TData>;

	/**
	 * Gets the target of a relationship. For example, if we say
	 * `world.target(entity, ChildOf)`, this returns the parent entity.
	 * @param entity The entity using a relationship pair.
	 * @param relation The "relationship" component/tag (e.g., ChildOf).
	 * @param index If multiple targets exist, specify an index. Defaults to 0.
	 */
	target(entity: Entity, relation: Entity, index?: number): Entity | undefined;

	/**
	 * Cleans up the world by removing empty archetypes and rebuilding the archetype collections.
	 * This helps maintain memory efficiency by removing unused archetype definitions.
	 */
	cleanup(): void;

	/**
	 * Clears all components and relationships from the given entity, but
	 * does not delete the entity from the world.
	 * @param entity The entity to clear.
	 */
	clear(entity: Entity): void;

	/**
	 * Deletes an entity (and its components/relationships) from the world entirely.
	 * @param entity The entity to delete.
	 */
	delete(entity: Entity): void;

	/**
	 * Adds a component (with no value) to the entity.
	 * @param entity The target entity.
	 * @param component The component (or tag) to add.
	 */
	add(entity: Entity, component: Id<undefined>): void;

	/**
	 * Assigns a value to a component on the given entity.
	 * @param entity The target entity.
	 * @param component The component definition (could be a Pair or Entity).
	 * @param value The value to store with that component.
	 */
	set<E extends Id<unknown>>(entity: Entity, component: E, value: InferComponent<E>): void;

	/**
	 * Removes a component from the given entity.
	 * @param entity The target entity.
	 * @param component The component to remove.
	 */
	remove(entity: Entity, component: Id): void;

	/**
	 * Retrieves the values of up to 4 components on a given entity. Missing
	 * components will return `undefined`.
	 * @param entity The entity to query.
	 * @param components Up to 4 components/tags to retrieve.
	 * @returns A tuple of data (or a single value), each possibly undefined.
	 */
	get<T extends [Id] | [Id, Id] | [Id, Id, Id] | [Id, Id, Id, Id]>(
		entity: Entity,
		...components: T
	): FlattenTuple<Nullable<InferComponents<T>>>;

	/**
	 * Returns `true` if the given entity has all of the specified components.
	 * A maximum of 4 components can be checked at once.
	 * @param entity The entity to check.
	 * @param components Upto 4 components to check for.
	 */
	has(entity: Entity, ...components: Id[]): boolean;

	/**
	 * Checks if an entity exists in the world.
	 * @param entity The entity to verify.
	 */
	contains(entity: Entity): boolean;

	/**
	 * Gets the parent (the target of a `ChildOf` relationship) for an entity,
	 * if such a relationship exists.
	 * @param entity The entity whose parent is queried.
	 */
	parent(entity: Entity): Entity | undefined;

	/**
	 * Searches the world for entities that match specified components.
	 * @param components The list of components to query.
	 * @returns A Query object to iterate over results.
	 */
	query<T extends Id[]>(...components: T): Query<InferComponents<T>>;

	/**
	 * Returns an iterator that yields all entities that have the specified component or relationship.
	 * @param id The component or relationship ID to search for
	 * @returns An iterator function that yields entities
	 */
	each(id: Id): IterableFunction<Entity>;

	/**
	 * Returns an iterator that yields all child entities of the specified parent entity.
	 * Uses the ChildOf relationship internally.
	 * @param parent The parent entity to get children for
	 * @returns An iterator function that yields child entities
	 */
	children(parent: Entity): IterableFunction<Entity>;
}

/**
 * Creates a composite key (pair)
 * @param pred The first entity (predicate)
 * @param obj The second entity (object)
 * @returns The composite key (pair)
 */
export function pair<P, O>(pred: Entity<P>, obj: Entity<O>): Pair<P, O>;

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
export function pair_first<P, O>(world: World, p: Pair<P, O>): Entity<P>;

/**
 * Gets the second entity (object) of a pair
 * @param pair The pair to get the second entity from
 * @returns The second entity (object) of the pair
 */
export function pair_second<P, O>(world: World, p: Pair<P, O>): Entity<O>;

export declare const OnAdd: Entity<(e: Entity) => void>;
export declare const OnRemove: Entity<(e: Entity) => void>;
export declare const OnSet: Entity<(e: Entity, value: unknown) => void>;
export declare const ChildOf: Tag;
export declare const Wildcard: Entity;
export declare const w: Entity;
export declare const OnDelete: Tag;
export declare const OnDeleteTarget: Tag;
export declare const Delete: Tag;
export declare const Remove: Tag;
export declare const Name: Entity<string>;
export declare const Rest: Entity;
