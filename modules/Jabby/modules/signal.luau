--[[

	A rudimentary signal class. Yielding may cause bugs.

]]

local signal = {}
signal.__index = signal

type Connection = { disconnect: (any?) -> (), reconnect: (any?) -> () }
export type Signal<T... = ...unknown> = {

	class_name: "Signal",

	connect: (Signal<T...>, callback: (T...) -> ()) -> Connection,
	wait: (Signal<T...>) -> T...,
	once: (Signal<T...>, callback: (T...) -> ()) -> Connection,

	callbacks: { [(T...) -> ()]: true },
}
export type SignalInternal<T... = ...unknown> = Signal<T...> & {
	fire: (SignalInternal<T...>, T...) -> (),
}

function signal.connect<T...>(self: Signal<T...>, callback: (T...) -> ())
	assert(type(callback) == "function")
	self.callbacks[callback] = true

	return {
		disconnect = function() self.callbacks[callback] = nil end,
		reconnect = function() self.callbacks[callback] = true end,
	}
end

function signal.fire<T...>(self: Signal<T...>, ...: T...)
	for callback in self.callbacks do
		callback(...)
	end
end

function signal.once<T...>(self: Signal<T...>, callback: (T...) -> ())
	local connection
	connection = self:connect(function(...)
		connection:disconnect()
		callback(...)
	end)

	return connection
end

function signal.wait<T...>(self: Signal<T...>)
	local thread = coroutine.running()

	local connection = self:connect(function(...) coroutine.resume(thread, ...) end)
	local packed = { coroutine.yield() }
	connection:disconnect()
	return unpack(packed)
end

local function new_signal<T...>(): (Signal<T...>, (T...) -> ())
	local self = setmetatable({
		class_name = "Signal",
		callbacks = {},
	}, signal)

	local function fire(...)
		for callback in self.callbacks :: any do
			callback(...)
		end
	end

	return self :: any, fire
end

return new_signal