--!strict
local jecs = require("@jecs")

type World = jecs.World
type Query<T...> = jecs.Query<T...>

type Id<T=any> = jecs.Id<T>

type Entity<T> = jecs.Entity<T>

export type Iter<T...> = (Observer<T...>) -> () -> (jecs.Entity, T...)

export type Observer<T...> = typeof(setmetatable(
	{} :: {
		iter: Iter<T...>,
		entities: { Entity<nil> },
		disconnect: (Observer<T...>) -> ()
	},
	{} :: {
		__iter: Iter<T...>,
	}
))

local function observers_new<T...>(
	query: Query<T...>,
	callback: ((Entity<nil>, Id<any>, value: any?) -> ())?
): Observer<T...>

	query:cached()

	local world = (query :: Query<T...> & { world: World }).world
	callback = callback

	local archetypes = {}
	local terms = query.ids
	local first = terms[1]

	local observers_on_create = world.observable[jecs.ArchetypeCreate][first]
	local observer_on_create = observers_on_create[#observers_on_create]
	observer_on_create.callback = function(archetype)
		archetypes[archetype.id] = true
	end
	local observers_on_delete = world.observable[jecs.ArchetypeDelete][first]
	local observer_on_delete = observers_on_delete[#observers_on_delete]
	observer_on_delete.callback = function(archetype)
		archetypes[archetype.id] = nil
	end

	local entity_index = world.entity_index :: any
	local i = 0
	local entities = {}

	local function emplaced<T, a>(
		entity: jecs.Entity<T>,
		id: jecs.Id<a>,
		value: a?
	)
		local r = entity_index.sparse_array[jecs.ECS_ID(entity)]

		local archetype = r.archetype

		if archetypes[archetype.id] then
			i += 1
			entities[i] = entity
			if callback ~= nil then
				callback(entity, id, value)
			end
		end
	end

	for _, term in terms do
		world:added(term, emplaced)
		world:changed(term, emplaced)
 	end

  	local function disconnect()
   		table.remove(observers_on_create, table.find(
     		observers_on_create,
       		observer_on_create
     	))

     	table.remove(observers_on_delete, table.find(
      		observers_on_delete,
        	observer_on_delete
       	))
   	end

    local function iter()
  		local row = i
  		return function()
 			if row == 0 then
     			i = 0
      			table.clear(entities)
      		end
           	local entity = entities[row]
           	row -= 1
           	return entity
        end
    end

  	local observer = {
   		disconnect = disconnect,
     	entities = entities,
     	__iter = iter,
      	iter = iter
   	}

    setmetatable(observer, observer)

    return (observer :: any) :: Observer<T...>
end

local function monitors_new<T...>(
	query: Query<T...>,
	callback: ((Entity<nil>, Id<any>, value: any?) -> ())?
): Observer<T...>

	query:cached()

	local world = (query :: Query<T...> & { world: World }).world

	local archetypes = {}
	local terms = query.ids
	local first = terms[1]

	local observers_on_create = world.observable[jecs.ArchetypeCreate][first]
	local observer_on_create = observers_on_create[#observers_on_create]
	observer_on_create.callback = function(archetype)
		archetypes[archetype.id] = true
	end
	local observers_on_delete = world.observable[jecs.ArchetypeDelete][first]
	local observer_on_delete = observers_on_delete[#observers_on_delete]
	observer_on_delete.callback = function(archetype)
		archetypes[archetype.id] = nil
	end
	local entity_index = world.entity_index :: any
	local i = 0
	local entities = {}

	local function emplaced<T, a>(
		entity: jecs.Entity<T>,
		id: jecs.Id<a>,
		value: a?
	)
		local r = jecs.entity_index_try_get_fast(
			entity_index, entity :: any) :: jecs.Record

		local archetype = r.archetype
		local EcsOnAdd = jecs.OnAdd :: jecs.Id

		if archetypes[archetype.id] then
			i += 1
			entities[i] = entity
			if callback ~= nil then
				callback(entity, EcsOnAdd, value)
			end
		end
	end

	local function removed(entity: jecs.Entity, component: jecs.Id)
		local EcsOnRemove = jecs.OnRemove :: jecs.Id
		if callback ~= nil then
			callback(entity, EcsOnRemove)
		end
	end

	for _, term in terms do
		world:added(term, emplaced)
		world:removed(term, removed)
 	end

 	local function disconnect()
  		table.remove(observers_on_create, table.find(
	  		observers_on_create,
	    	observer_on_create
	   	))

	   	table.remove(observers_on_delete, table.find(
	      	observers_on_delete,
	       	observer_on_delete
       	))
   	end

    local function iter()
  		local row = i
  		return function()
 			if row == 0 then
     			i = 0
     			table.clear(entities)
      		end
           	local entity = entities[row]
           	row -= 1
           	return entity
        end
    end

	local observer = {
  		disconnect = disconnect,
	   	entities = entities,
	   	__iter = iter,
       	iter = iter
   	}

    setmetatable(observer, observer)

    return (observer :: any) :: Observer<T...>
end

return {
	monitor = monitors_new,
	observer = observers_new
}
