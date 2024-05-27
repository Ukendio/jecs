# World

### World.new

World.new(): [World](../api-typesk.md#World)

Create a new world.

#### Returns
A new world

---

### World.entity

World.entity(world: [World](../api-types.md#World)): [Entity](../api-types.md#Entity)

Creates an entity in the world.

#### Returns
A new entiity id

---

### World.target

World.target(world: [World](../api-types.md#World), 
             entity: [Entity](../api-types.md#Entity), 
             rel: [Entity](../api-types.md#Entity)): [Entity](../api-types.md#Entity)

Get the target of a relationship.

This will return a target (second element of a pair) of the entity for the specified relationship. 

#### Parameters
    world	The world.
    entity  The entity.
    rel     The relationship between the entity and the target.

#### Returns

The first target for the relationship

--- 

### World.add

World.add(world: [World](../api-types.md#World), 
          entity: [Entity](../api-types.md#Entity), 
          id: [Entity](../api-types.md#Entity)): [Entity](..#api-types.md#Entity)

Add a (component) id to an entity.

This operation adds a single (component) id to an entity. 
If the entity already has the id, this operation will have no side effects.

#### Parameters
    world   The world.
    entity  The entity.
    id      The id to add. 

--- 

### World.remove

World.remove(world: [World](../api-types#World), 
             entity: [Entity](../api-types#Entity), 
             id: [Entity](../api-types#Entity)): [Entity](../api-types#Entity)

Remove a (component) id to an entity.

This operation removes a single (component) id to an entity. 
If the entity already has the id, this operation will have no side effects.

#### Parameters
    world   The world.
    entity  The entity.
    id      The id to add. 

---

### World.get

World.get(world: [World](../api-types.md#World), 
          entity: [Entity](../api-types.md#Entity), 
          id: [Entity](../api-types.md#Entity)): any

Gets the component data.  

#### Parameters
    world	The world.
    entity  The entity.
    id      The id of component to get. 

#### Returns
The component data, nil if the entity does not have the componnet.

---

### World.set

World.set(world: [World](../api-types.md#World), 
          entity: [Entity](../api-types.md#Entity), 
          id: [Entity](../api-types.md#Entity)
          data: any)

Set the value of a component.

#### Parameters
    world   The world.
    entity  The entity.
    id      The id of the componment set. 
    data    The data to the component.

---

### World.query

World.query(world: [World](../api-types.md#World), 
            ...: [Entity](../api-types.mdEntity)): [QueryIter](../api-types.md#QueryIter)

Create a QueryIter from the list of filters.

#### Parameters
    world   The world.
    ...     The collection of components to match entities against.

#### Returns

The query iterator.

---

# Pair 

### pair

pair(first: [Entity](../api-types#Entity), 
          second: [Entity](../api-types#Entity)): [Entity](../api-types#Entity)

Creates a composite key.

#### Parameters
    first   The first element.
    second  The second element.

#### Returns

The pair of the two elements

---

### IS_PAIR

jecs.IS_PAIR(id: [Entity](../api-types#Entity)): boolean

Creates a composite key.

#### Parameters
    id  The id to check.

#### Returns

If id is a pair.

---

# Constants

### OnAdd

---

### OnRemove

---

### Rest

---

### OnSet

---

### Wildcard

Matches any id, returns all matches.
