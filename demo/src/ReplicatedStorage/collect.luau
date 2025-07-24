
--!strict
local function collect(signal)
	local enqueued = {}

	local i = 0

	local connection = signal:Connect(function(...)
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

type Signal<T... = ...any> = {
    Connect: (self: Signal<T...>, callback: (T...) -> ()) -> RBXScriptConnection,
    ConnectParallel: (self: Signal<T...>, callback: (T...) -> ()) -> RBXScriptConnection,
    Once: (self: Signal<T...>, callback: (T...) -> ()) -> RBXScriptConnection,
    Wait: (self: Signal<T...>) -> (T...)
}

return collect :: <T...>(Signal<T...>) -> (() -> (T...), RBXScriptConnection)
