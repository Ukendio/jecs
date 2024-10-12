local jecs = require(game:GetService("ReplicatedStorage").ecs)
type World = jecs.World

type Tracker<T> = {
	track: (
		world: World,
		fn: (
			changes: {
				added: () -> () -> (number, T),
				removed: () -> () -> number,
				changed: () -> () -> (number, T, T),
			}
		) -> ()
	) -> (),
}

type Entity<T = any> = number & { __nominal_type_dont_use: T }

local function diff(a, b)
	local size = 0
	for k, v in a do
		if b[k] ~= v then
			return true
		end
		size += 1
	end
	for k, v in b do
		size -= 1
	end

	if size ~= 0 then
		return true
	end

	return false
end

local function ChangeTracker<T>(world: World, T: Entity<T>): Tracker<T>
	local sparse = world.entityIndex.sparse
	local PreviousT = jecs.pair(jecs.Rest, T)
	local add = {}
	local added
	local removed
	local is_trivial

	local function changes_added()
		added = true
		local q = world:query(T):without(PreviousT):drain()
		return function()
			local id, data = q.next()
			if not id then
				return nil
			end

			is_trivial = typeof(data) ~= "table"

			add[id] = data

			return id, data
		end
	end

	local function changes_changed()
		local q = world:query(T, PreviousT):drain()

		return function()
			local id, new, old = q.next()
			while true do
				if not id then
					return nil
				end

				if not is_trivial then
					if diff(new, old) then
						break
					end
				elseif new ~= old then
					break
				end

				id, new, old = q.next()
			end

			local record = sparse[id]
			local archetype = record.archetype
			local column = archetype.records[PreviousT].column
			local data = if is_trivial then new else table.clone(new)
			archetype.columns[column][record.row] = data

			return id, old, new
		end
	end

	local function changes_removed()
		removed = true

		local q = world:query(PreviousT):without(T):drain()
		return function()
			local id = q.next()
			if id then
				world:remove(id, PreviousT)
			end
			return id
		end
	end

	local changes = {
		added = changes_added,
		changed = changes_changed,
		removed = changes_removed,
	}

	local function track(fn)
		added = false
		removed = false

		fn(changes)

		if not added then
			for _ in changes_added() do
			end
		end

		if not removed then
			for _ in changes_removed() do
			end
		end

		for e, data in add do
			world:set(e, PreviousT, if is_trivial then data else table.clone(data))
		end
	end

	local tracker = { track = track }

	return tracker
end

return ChangeTracker
