/*
 * The base type for entities.
 * This type indicates that the entity cannot be used to `tag` other entities
 * and cannot be used used as a component to associate any kind of data with itself.
 */
export type Id = number & {
    readonly __nominal_Id: unique symbol;
};

/*
 * An entity with no associated data when used as a component.
 * This entity however could still be used to 'tag' other entities.
 *
 * You could go further and downcast this type to `Id`
 * indicating that the entity is intended to only store other entities.
 */
export type Tag = Id & {
    readonly __nominal_Tag: unique symbol;
};

/**
 * A unique identifier in the world, entity.
 * This identifier is associated with `TData` data when this entity is used as a component.
 */
export type Entity<TData = unknown> = Tag & {
    readonly __nominal_Entity: unique symbol;
    readonly __type_TData: TData;
};

type InferComponent<TValue> = TValue extends Entity<infer TData> ? TData : never;

type FlattenTuple<TItems extends any[]> = TItems extends [infer TValue] ? TValue : LuaTuple<TItems>;

type Undefinedable<TItems extends any[]> = {
    [TKey in keyof TItems]: TItems[TKey] | undefined;
};

type InferComponents<TComponents extends Entity[]> = {
	[TKey in keyof TComponents]: InferComponent<TComponents[TKey]>;
};

type TupleForWorldGet = [Entity] | [Entity, Entity] | [Entity, Entity, Entity] | [Entity, Entity, Entity, Entity];

type Iter<T extends any[]> = IterableFunction<LuaTuple<[Entity, ...T]>>;

export type Query<T extends any[]> = {
	/**
	 * Returns an iterator that returns a tuple of an entity and queried components
	 */
	iter(): Iter<T>;

	/**
	 * Modifies the query to include specified components
	 * @param components The components to include
	 * @returns Modified Query
	 */
	with(...components: Tag[]): Query<T>;

	/**
	 * Modifies the Query to exclude specified components
	 * @param components The components to exclude
	 * @returns Modified Query
	 */
	without(...components: Tag[]): Query<T>;
} & Iter<T>;

export class World {
	/**
	 * Creates a new World
	 */
	constructor();

	/**
	 * Creates a new entity.
     *
     * If your intention is to use this entity as a component associated with some data
     * then you should provide the type parameter.
     *
	 * @returns Entity
	 */
	entity<TData = never>(): [TData] extends [never] ? Id : Entity<TData>;

	/**
	 * Creates a new entity located in the first 256 ids.
     *
	 * These should be used for static components for fast access.
	 * @returns Entity<TData>
	 */
	component<TData = unknown>(): Entity<TData>;

	/**
	 * Gets the target of a relationship. For example, when a user calls
	 * `world.target(entity, ChildOf)`, you will obtain the parent entity.
	 * @param entity Entity
	 * @param relation The Relationship
	 * @returns The Parent Entity if it exists
	 */
	target(entity: Id, relation: Entity): Entity | undefined;

	/**
	 * Gets the target of a relationship at a specific index.
	 * For example, when a user calls `world.target(entity, ChildOf(parent), 0)`,
	 * you will obtain the parent entity.
	 * @param entity Entity
	 * @param relation The Relationship
	 * @param index Target index
	 * @returns The Parent Entity if it exists
	 */
	target(entity: Id, relation: Entity, index: number): Entity | undefined;

	/**
	 * Clears an entity from the world.
	 * @param entity Entity to be cleared
	 */
	clear(entity: Id): void;

	/**
	 * Deletes an entity and all its related components and relationships.
	 * @param entity Entity to be destroyed
	 */
	delete(entity: Id): void;

	/**
	 * Adds a component to the entity with no value.
     *
	 * @param entity Target Entity
	 * @param tag Tag
	 */
	add(entity: Id, tag: Tag): void;

	/**
	 * Assigns a value to a component on the given entity
	 * @param entity Target Entity
	 * @param component Target Component
	 * @param value Component Value
	 */
	set<TData>(entity: Id, component: Entity<TData>, value: NoInfer<TData>): void;

	/**
	 * Removes a component from the given entity
	 * @param entity Target Entity
	 * @param component Target Component
	 */
	remove(entity: Id, component: Tag): void;

	/**
	 * Retrieves the values of specified components for an entity.
	 * Some values may not exist when called.
	 * A maximum of 4 components are allowed at a time.
	 * @param entity Target Entity
	 * @param components Target Components
	 * @returns Data associated with target components if it exists.
	 */
	get<TComponents extends TupleForWorldGet>(entity: Id, ...components: TComponents): FlattenTuple<Undefinedable<InferComponents<TComponents>>>;

	/**
	 * Returns whether the entity has the specified components.
	 * A maximum of 4 components are allowed at a time.
     *
	 * @param entity Target Entity
	 * @param components Target Components
	 * @returns If the entity contains the components
	 */
	has(entity: Id, ...components: Tag[]): boolean;

	/**
	 * Checks if an entity exists in the world
	 * @param entity Entity to check
	 * @returns Whether the entity exists in the world
	 */
	contains(entity: Id): boolean;

	/**
	 * Get parent (target of ChildOf relationship) for entity.
	 * If there is no ChildOf relationship pair, it will return undefined.
	 * @param entity Target Entity
	 * @returns Parent Entity or undefined
	 */
	parent(entity: Id): Entity | undefined;

	/**
	 * Searches the world for entities that match a given query
	 * @param components Queried Components
	 * @returns Query
	 */
	query<TComponents extends Entity[]>(...components: TComponents): Query<InferComponents<TComponents>>;
}

/**
 * Creates a composite key (pair).
 *
 * @param pred The first entity (predicate)
 * @param obj The second entity (object)
 * @returns The composite key (pair)
 */
export function pair<TPredicate, TObject>(pred: Entity<TPredicate>, obj: Entity<TObject>): Entity<TPredicate>;

/**
 * Checks if the entity is a composite key (pair)
 * @param value The entity to check
 * @returns If the entity is a pair
 */
export function IS_PAIR(value: Id): value is Entity;

/**
 * Gets the first entity (predicate) of a pair
 * @param pair The pair to get the first entity from
 * @returns The first entity (predicate) of the pair
 */
export function pair_first(world: World, pair: Entity): Entity;

/**
 * Gets the second entity (object) of a pair
 * @param pair The pair to get the second entity from
 * @returns The second entity (object) of the pair
 */
export function pair_second(world: World, pair: Entity): Entity;

export const Component: Entity;

export const OnAdd: Entity<(entity: Entity) => void>;
export const OnRemove: Entity<(entity: Entity) => void>;
export const OnSet: Entity<(entity: Entity, value: unknown) => void>;
export const ChildOf: Entity;
export const Wildcard: Entity;
export const w: Entity;
export const OnDelete: Entity;
export const OnDeleteTarget: Entity;
export const Delete: Entity;
export const Remove: Entity;
export const Name: Entity<string>;
export const Rest: Entity;
