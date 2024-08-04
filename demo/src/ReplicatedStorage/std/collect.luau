--!nonstrict

--[[
	local signal = Signal.new() :: Signal.Signal<string, string>
	local events = collect(signal)
	local function system(world)
		for id, str1, str2 in events do
			--
		end
	end
]]

--[[
original author by @memorycode

MIT License

Copyright (c) 2024 Michael

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

type Signal<T...> = { [any]: any }
local function collect<T...>(event: Signal<T...>)
	local storage = {}
	local mt = {}
	local iter = function()
		local n = #storage
		return function()
			if n <= 0 then
				mt.__iter = nil
				return nil
			end

			n -= 1
			return n + 1, unpack(table.remove(storage, 1) :: any)
		end
	end

	local disconnect = event:Connect(function(...)
		table.insert(storage, { ... })
		mt.__iter = iter
	end)

	setmetatable(storage, mt)
	return (storage :: any) :: () -> (number, T...), function()
		disconnect()
	end
end

return collect
