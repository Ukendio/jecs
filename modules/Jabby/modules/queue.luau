--- Licensed under MIT from centau_ri
export type Queue<T...> = typeof(setmetatable(
	{} :: {
		add: (self: Queue<T...>, T...) -> (),
		clear: (self: Queue<T...>) -> (),
		iter: (self: Queue<T...>) -> () -> T...,
	},
	{} :: {
		__len: (self: Queue<T...>) -> number,
		__iter: (self: Queue<T...>) -> () -> T...,
	}
))

type Array<T> = { T }

local Queue = {}
do
	Queue.__index = Queue

	type _Queue = Queue<...any> & {
		size: number,
		columns: Array<Array<unknown>>,
	}

	function Queue.new<T...>(): Queue<T...>
		local self: _Queue = setmetatable({
			size = 0,
			columns = {},
		}, Queue) :: any

		setmetatable(self.columns, {
			__index = function(columns: Array<Array<unknown>>, idx: number)
				columns[idx] = {}
				return columns[idx]
			end,
		})

		return self :: Queue<T...>
	end

	function Queue.add(self: _Queue, ...: unknown)
		-- iteration will stop if first value is `nil`
		assert((...) ~= nil, "first argument cannot be nil")

		local columns = self.columns
		local n = self.size + 1
		self.size = n

		for i = 1, select("#", ...) do
			columns[i][n] = select(i, ...)
		end
	end

	function Queue.clear(self: _Queue)
		self.size = 0
		for _, column in next, self.columns do
			table.clear(column)
		end
	end

	local function iter(self: _Queue)
		local columns = self.columns
		local n = self.size
		local i = 0

		if #columns <= 1 then
			local column = columns[1]
			return function()
				i += 1
				local value = column[i]
				if i == n then self:clear() end
				return value
			end
		else
			local tuple = table.create(#columns)
			return function()
				i += 1
				for ci, column in next, columns do
					tuple[ci] = column[i]
				end
				if i == n then self:clear() end
				return unpack(tuple)
			end
		end
	end

	Queue.iter = iter
	Queue.__iter = iter

	function Queue.__len(self: _Queue)
		return self.size
	end
end

type ISignal<T...> = {
	connect: (self: any, listener: (T...) -> ()) -> (),
} | {
	Connect: (self: any, listener: (T...) -> ()) -> (),
}

local queue_create = function<T...>(signal: ISignal<T...>?): Queue<T...>
	local queue = Queue.new()

	if signal then
		local connector = (signal :: any).connect or (signal :: any).Connect
		assert(connector, "signal has no member `connect()`")
		connector(signal, function(...)
			queue:add(...)
		end)
	end

	return queue
end :: (<T...>() -> Queue<T...>) & (<T...>(signal: ISignal<T...>) -> Queue<T...>)

return queue_create