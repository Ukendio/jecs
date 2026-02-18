--[[

Implements a form of dependency injection to save the need from passing data
as props through intermediate components.

]]

export type Context<T = nil> = {
	default_value: T,
	_values: {[thread]: T},

	provide: <U>(Context<T>, callback: () -> U) -> (new: T) -> U,
	consume: (Context<T>) -> T
}

type ContextNoDefault<T> = {
	_values: {[thread]: T},

	provide: <U>(Context<T>, callback: () -> U) -> (new: T) -> U,
	consume: (Context<T>) -> T?
}

local function provide<T, U>(context: Context<T>, callback: () -> U)
	return function(new: T): U
		local thread = coroutine.running()
		local old = context._values[thread]

		context._values[thread] = new

		local ok, value = pcall(callback)

		context._values[thread] = old
		
		if not ok then
			error(`provided callback errored with "{value}"`, 2)
		end

		return value
	end :: (new: T) -> U
end

local function consume<T>(context: Context<T>): T
	local thread = coroutine.running()
	return context._values[thread] or context.default_value
end

local function create_context<T>(default_value: T?): Context<T>
	return {
		default_value = default_value,
		_values = {},

		provide = provide :: any,
		consume = consume
	}
end

return create_context :: (<T>(default_value: T) -> Context<T>) & (<T>() -> ContextNoDefault<T>)