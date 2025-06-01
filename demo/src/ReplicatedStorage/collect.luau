local function collect<T...>(
	signal: {
		Connect: (RBXScriptSignal<T...>, fn: (T...) -> ()) -> RBXScriptConnection
	}
): () -> (T...)
	local enqueued = {}

	local i = 0

	local connection = (signal :: any):Connect(function(...)
		table.insert(enqueued, { ... })
		i += 1
	end)

	return function(): any
		if i == 0 then
			return
		end

		i -= 1

		local args: any = table.remove(enqueued, 1)

		return unpack(args)
	end, connection
end

return collect
