local jecs = require("@jecs")
local world = jecs.world()

--[[
	Entities represent things in a game. In a game there may be entities of
	characters, buildings, projectiles, particle effects etc.

	By itself, an entity is just an unique entity identifier without any data.
	An entity identifier contains information about the entity itself and its generation.
]]


-- Creates a new entity with no components and returns its identifier
local entity = world:entity()
print(entity)

-- The entity member function also accepts an overload that allows you to create
-- an entity with a desired id which bypasses the entity range.
world:entity(42)

--[[

	The entity ID will have a corresponding entity
	record that essentially just keeps indices into arrays of data.
	The format of the entity record is:

	record: {
		row: number,
	}

--]]

-- You can retrieve an entity's record by using one of the jecs function:

local record = jecs.record(world, entity)
print(record)

--[[

	Underneath the ECS the entity ID and its record will be stored in two separate arrays.
	A dense array and a sparse array. Other than the fact that there is
	two arrays is an unimportant implementation detail.
	We just use these distinct terms to differentiate them. The format is:

		dense_array: { u53 }
		sparse_array: { [u24]: record }

	The entity ID that you operate with is an element in the dense array with
	the u53 number type. In reality, there is no such thing as a u53 number
	type. In luau it is actually all just doubles (IEEE-754 f64).

	However the size of the integer mantissa in a double is 53 bits, so it
	can represent integers with full precision up to 2^53.

	As a refresher here is the IEEE-754 f64 (double) bit layout:

	bit index: 63              52 51                         0
		      |                 | |                          |
		      v                 v v                          v
	+---------+---------------+-------------------------------+
	|  sign   |    exponent   |        mantissa / fraction    |
	| (1 bit) |   (11 bits)   |          (52 bits)            |
	+---------+---------------+-------------------------------+

	Entity IDs use 48 bits which is well within the range for the mantissa.
	This is useful to know because it allows the ECS to put a lot of information
	in this opaque ID number such as the index into the sparse_array and a generation.

	A generation is a number that increments everytime an entity index is
	reused. By embedding this counter into the entity ID, any stale handle
	referring to a previous entity of that index becomes invalid.
	Because programmers are not perfect and often forget about dangling pointers
	as a result of storing and referencing entities outside of the ECS.

	If the index 10 has been used for an entity, dies, and gets reused.
	The new entity becomes index 10, generation 2.

	The layout of the ID itself is:

	[ 47 ........ 24 ][ 23 ........ 0 ]
	|   generation    |     index     |
	|    (24 bits)    |   (24 bits)   |

	The index is used to lookup the corresponding record for the entity such as:

	record = sparse_array[downcast(u24)(dense_array[n])]
--]]

-- It is possible to read the index and the generation of an entity ID
-- using the public API with the following:

local ECS_ID = jecs.ECS_ID
local ECS_GENERATION = jecs.ECS_GENERATION

local index = ECS_ID(entity)
local generation = ECS_GENERATION(entity)

print(`Entity's index and generation are {index} and {generation} respectively`)

-- A notable detail about entity IDs is that they can become very large
-- as the generation increases. This is because the bits
-- further to the left represent much larger powers of two.

world:delete(entity)

local recycled_entity = world:entity()

print(`This is a huuuuge number {recycled_entity}`)
print(`The recycled entity's generation incremented to {ECS_GENERATION(recycled_entity)} `)
print(`However it retains the old index at {ECS_ID(recycled_entity)}`)

