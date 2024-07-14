--------------------------------------------------------------------------------
-- testkit.luau
-- v0.7.3
--------------------------------------------------------------------------------

local disable_ansi = false

local color = {
	white_underline = function(s: string): string
		return if disable_ansi then s else `\27[1;4m{s}\27[0m`
	end,

	white = function(s: string): string
		return if disable_ansi then s else `\27[37;1m{s}\27[0m`
	end,

	green = function(s: string): string
		return if disable_ansi then s else `\27[32;1m{s}\27[0m`
	end,

	red = function(s: string): string
		return if disable_ansi then s else `\27[31;1m{s}\27[0m`
	end,

	yellow = function(s: string): string
		return if disable_ansi then s else `\27[33;1m{s}\27[0m`
	end,

	red_highlight = function(s: string): string
		return if disable_ansi then s else `\27[41;1;30m{s}\27[0m`
	end,

	green_highlight = function(s: string): string
		return if disable_ansi then s else `\27[42;1;30m{s}\27[0m`
	end,

	gray = function(s: string): string
		return if disable_ansi then s else `\27[38;1m{s}\27[0m`
	end,

	orange = function(s: string): string
	   return if disable_ansi then s else `\27[38;5;208m{s}\27[0m`
	end,
}

local function convert_units(unit: string, value: number): (number, string)
	local sign = math.sign(value)
	value = math.abs(value)

	local prefix_colors = {
		[4] = color.red,
		[3] = color.red,
		[2] = color.yellow,
		[1] = color.yellow,
		[0] = color.green,
		[-1] = color.red,
		[-2] = color.yellow,
		[-3] = color.green,
		[-4] = color.red,
	}

	local prefixes = {
		[4] = "T",
		[3] = "G",
		[2] = "M",
		[1] = "k",
		[0] = " ",
		[-1] = "m",
		[-2] = "u",
		[-3] = "n",
		[-4] = "p",
	}

	local order = 0

	while value >= 1000 do
		order += 1
		value /= 1000
	end

	while value ~= 0 and value < 1 do
		order -= 1
		value *= 1000
	end

	if value >= 100 then
		value = math.floor(value)
	elseif value >= 10 then
		value = math.floor(value * 1e1) / 1e1
	elseif value >= 1 then
		value = math.floor(value * 1e2) / 1e2
	end

	return value * sign, prefix_colors[order](prefixes[order] .. unit)
end

local WALL = color.gray "│"

--------------------------------------------------------------------------------
-- Testing
--------------------------------------------------------------------------------

type Test = {
	name: string,
	case: Case?,
	cases: { Case },
	duration: number,
	error: {
		message: string,
		trace: string,
	}?,
}

type Case = {
	name: string,
	result: number,
	line: number?,
}

local PASS, FAIL, NONE, ERROR, SKIPPED = 1, 2, 3, 4, 5

local skip = false
local test: Test?
local tests: { Test } = {}

local function output_test_result(test: Test)
	print(color.white(test.name))

	for _, case in test.cases do
		local status = ({
			[PASS] = color.green "PASS",
			[FAIL] = color.red "FAIL",
			[NONE] = color.orange "NONE",
			[ERROR] = color.red "FAIL",
			[SKIPPED] = color.yellow "SKIP"
		})[case.result]

		local line = case.result == FAIL and color.red(`{case.line}:`) or ""

		print(`{status}{WALL} {line}{color.gray(case.name)}`)
	end

	if test.error then
		print(color.gray "error: " .. color.red(test.error.message))
		print(color.gray "trace: " .. color.red(test.error.trace))
	else
		print()
	end
end

local function CASE(name: string)
    skip = false
	assert(test, "no active test")

	local case = {
		name = name,
		result = NONE,
	}

	test.case = case
	table.insert(test.cases, case)
end

local function CHECK<T>(value: T, stack: number?): T?
	assert(test, "no active test")

	local case = test.case

	if not case then
		CASE ""
		case = test.case
	end

	assert(case, "no active case")

	if case.result ~= FAIL then
		case.result = value and PASS or FAIL
		if skip then
		    case.result = SKIPPED
		end
		case.line = debug.info(stack and stack + 1 or 2, "l")
	end

	return value
end

local function TEST(name: string, fn: () -> ())
	local active = test
	assert(not active, "cannot start test while another test is in progress")

	test = {
		name = name,
		cases = {},
		duration = 0,
	}
	assert(test)

	table.insert(tests, test)

	local start = os.clock()
	local err
	local success = xpcall(fn, function(m: string)
		err = { message = m, trace = debug.traceback(nil, 2) }
	end)
	test.duration = os.clock() - start

	if not test.case then CASE "" end
	assert(test.case, "no active case")

	if not success then
		test.case.result = ERROR
		test.error = err
	end

	test = nil
end

local function FINISH(): boolean
	local success = true
	local total_cases = 0
	local passed_cases = 0
	local duration = 0

	for _, test in tests do
		duration += test.duration
		for _, case in test.cases do
			total_cases += 1
			if case.result == PASS or case.result == NONE or case.result == SKIPPED then
				passed_cases += 1
			else
				success = false
			end
		end

		output_test_result(test)
	end

	print(
		color.gray(
			string.format(
				`{passed_cases}/{total_cases} test cases passed in %.3f ms.`,
				duration * 1e3
			)
		)
	)

	local fails = total_cases - passed_cases

	print(
		(fails > 0 and color.red or color.green)(
			`{fails} {fails == 1 and "fail" or "fails"}`
		)
	)

	return success, table.clear(tests)
end

local function SKIP(name: string)
	skip = true
end

--------------------------------------------------------------------------------
-- Benchmarking
--------------------------------------------------------------------------------

type Bench = {
	time_start: number?,
	memory_start: number?,
	iterations: number?,
}

local bench: Bench?

function START(iter: number?): number
	local n = iter or 1
	assert(n > 0, "iterations must be greater than 0")
	assert(bench, "no active benchmark")
	assert(not bench.time_start, "clock was already started")

	bench.iterations = n
	bench.memory_start = gcinfo()
	bench.time_start = os.clock()
	return n
end

local function BENCH(name: string, fn: () -> ())
	local active = bench
	assert(not active, "a benchmark is already in progress")

	bench = {}
	assert(bench);
	(collectgarbage :: any) "collect"

	local mem_start = gcinfo()
	local time_start = os.clock()
	local err_msg: string?

	local success = xpcall(fn, function(m: string)
		err_msg = m .. debug.traceback(nil, 2)
	end)

	local time_stop = os.clock()
	local mem_stop = gcinfo()

	if not success then
		print(`{WALL}{color.red "ERROR"}{WALL} {name}`)
		print(color.gray(err_msg :: string))
	else
		time_start = bench.time_start or time_start
		mem_start = bench.memory_start or mem_start

		local n = bench.iterations or 1
		local d, d_unit = convert_units("s", (time_stop - time_start) / n)
		local a, a_unit =
			convert_units("B", math.round((mem_stop - mem_start) / n * 1e3))

		local function round(x: number): string
			return x > 0
					and x < 10
					and (x - math.floor(x)) > 0
					and string.format("%2.1f", x)
				or string.format("%3.f", x)
		end

		print(
			string.format(
				`%s %s %s %s{WALL} %s`,
				color.gray(round(d)),
				d_unit,
				color.gray(round(a)),
				a_unit,
				color.gray(name)
			)
		)
	end

	bench = nil
end

--------------------------------------------------------------------------------
-- Printing
--------------------------------------------------------------------------------

local function print2(v: unknown)
	type Buffer = { n: number, [number]: string }
	type Cyclic = { n: number, [{}]: number }

	-- overkill concatenationless string buffer
	local function tos(value: any, stack: number, str: Buffer, cyclic: Cyclic)
		local TAB = "    "
		local indent = table.concat(table.create(stack, TAB))

		if type(value) == "string" then
			local n = str.n
			str[n + 1] = '"'
			str[n + 2] = value
			str[n + 3] = '"'
			str.n = n + 3
		elseif type(value) ~= "table" then
			local n = str.n
			str[n + 1] = value == nil and "nil" or tostring(value)
			str.n = n + 1
		elseif next(value) == nil then
			local n = str.n
			str[n + 1] = "{}"
			str.n = n + 1
		else -- is table
			local tabbed_indent = indent .. TAB

			if cyclic[value] then
				str.n += 1
				str[str.n] = color.gray(`CYCLIC REF {cyclic[value]}`)
				return
			else
				cyclic.n += 1
				cyclic[value] = cyclic.n
			end

			str.n += 3
			str[str.n - 2] = "{ "
			str[str.n - 1] = color.gray(tostring(cyclic[value]))
			str[str.n - 0] = "\n"

			local i, v = next(value, nil)
			while v ~= nil do
				local n = str.n
				str[n + 1] = tabbed_indent

				if type(i) ~= "string" then
					str[n + 2] = "["
					str[n + 3] = tostring(i)
					str[n + 4] = "]"
					n += 4
				else
					str[n + 2] = tostring(i)
					n += 2
				end

				str[n + 1] = " = "
				str.n = n + 1

				tos(v, stack + 1, str, cyclic)

				i, v = next(value, i)

				n = str.n
				str[n + 1] = v ~= nil and ",\n" or "\n"
				str.n = n + 1
			end

			local n = str.n
			str[n + 1] = indent
			str[n + 2] = "}"
			str.n = n + 2
		end
	end

	local str = { n = 0 }
	local cyclic = { n = 0 }
	tos(v, 0, str, cyclic)
	print(table.concat(str))
end

--------------------------------------------------------------------------------
-- Equality
--------------------------------------------------------------------------------

local function shallow_eq(a: {}, b: {}): boolean
	if #a ~= #b then return false end

	for i, v in next, a do
		if b[i] ~= v then return false end
	end

	for i, v in next, b do
		if a[i] ~= v then return false end
	end

	return true
end

local function deep_eq(a: {}, b: {}): boolean
	if #a ~= #b then return false end

	for i, v in next, a do
		if type(b[i]) == "table" and type(v) == "table" then
			if deep_eq(b[i], v) == false then return false end
		elseif b[i] ~= v then
			return false
		end
	end

	for i, v in next, b do
		if type(a[i]) == "table" and type(v) == "table" then
			if deep_eq(a[i], v) == false then return false end
		elseif a[i] ~= v then
			return false
		end
	end

	return true
end

--------------------------------------------------------------------------------
-- Return
--------------------------------------------------------------------------------

return {
	test = function()
		return TEST, CASE, CHECK, FINISH, SKIP
	end,

	benchmark = function()
		return BENCH, START
	end,

	disable_formatting = function()
		disable_ansi = true
	end,

	print = print2,

	seq = shallow_eq,
	deq = deep_eq,

	color = color,
}
