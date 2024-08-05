type Query<T extends unknown[]> = {

    /**
     * this: Query<T> is necessary to use a colon instead of a period for emits.
     */

    /**
     * Resets the Iterator for a query.
     */
    drain: (this: Query<T>) => Query<T>
    /**
     * Modifies the query to include specified components, but will not include the values.
     * @param components The components to include
     * @returns Modified Query
     */
    with: (this: Query<T>, ...components: Entity[]) => Query<T>
    /**
     * Modifies the Query to exclude specified components
     * @param components The components to exclude
     * @returns Modified Query
     */
    without: (this: Query<T>, ...components: Entity[]) => Query<T>;
    /**
     * Modifies component data with a callback function
     * @param fn The function to modify data
     */
    replace: (this: Query<T>, fn: (...components: T) => FlattenTuple<T>) => void;
} & IterableFunction<LuaTuple<[Entity, ...T]>>;

// Utility Types
export type Entity<T = unknown> = number & { __nominal_type_dont_use: T };
export type EntityType<T> = T extends Entity<infer A> ? A : never;
export type InferComponents<A extends Entity[]> = {
    [K in keyof A]: EntityType<A[K]>;
};
type Nullable<T extends unknown[]> = {
    [K in keyof T]: T[K] | undefined;
};
type FlattenTuple<T extends any[]> = T extends [infer U] ? U : LuaTuple<T>;

// Utility type for world:get
type TupleForWorldGet =
    | [Entity]
    | [Entity, Entity]
    | [Entity, Entity, Entity]
    | [Entity, Entity, Entity, Entity]
    | [Entity, Entity, Entity, Entity, Entity]

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
     * `world.target(id, ChildOf(parent))`, you will obtain the parent entity.
     * @param id Entity
     * @param relation The Relationship
     * @returns The Parent Entity if it exists
     */
    target(id: Entity, relation: Entity): Entity | undefined;

    /**
     * Clears an entity from the world.
     * @praram id Entity to be cleared
     */
    clear(id: Entity): void;

    /**
     * Deletes an entity and all its related components and relationships.
     * For most situations, you should be using the clear method instead of deletion.
     * @param id Entity to be destroyed
     */
    delete(id: Entity): void;

    /**
     * Adds a component to the entity with no value
     * @param id Target Entity
     * @param component Component
     */
    add<T>(id: Entity, component: Entity<T>): void;

    /**
     * Assigns a value to a component on the given entity
     * @param id Target Entity
     * @param component Target Component
     * @param data Component Data
     */
    set<T>(id: Entity, component: Entity<T>, data: T): void;

    /**
     * Removes a component from the given entity
     * @param id Target Entity
     * @param component Target Component
     */
    remove(id: Entity, component: Entity): void;

    // Manually typed out get since there is a hard limit.

    /**
     * Retrieves the values of specified components for an entity.
     * Some values may not exist when called.
     * A maximum of 5 components are allowed at a time.
     * @param id Target Entity
     * @param components Target Components
     * @returns Data associated with target components if it exists.
     */
    get<T extends TupleForWorldGet>(id: Entity, ...components: T): FlattenTuple<Nullable<InferComponents<T>>>

    /**
     * Searches the world for entities that match a given query
     * @param components Queried Components
     * @returns Query
     */
    query<T extends Entity[]>(...components: T): Query<InferComponents<T>>;
}

/**
 * Creates a composite key.
 * @param pred The first entity
 * @param obj The second entity
 * @returns The composite key
 */
export const pair: (pred: Entity, obj: Entity) => Entity;

/**
 * Checks if the entity is a composite key
 * @param e The entity to check
 * @returns If the entity is a pair
 */
export const IS_PAIR: (e: Entity) => boolean;

/**
 * Built-in Component used to find every component id
 */
export const Component: Entity;

export const OnAdd: Entity;
export const OnRemove: Entity;
export const OnSet: Entity;
export const Wildcard: Entity;
export const Rest: Entity;
