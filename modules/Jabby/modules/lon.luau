--!strict
local function stream(input: string)

	local pos = 0
	local line = 1
	local col = 1

	local function peek(): string
		return string.sub(input, pos+1, pos+1)
	end

	local function next(): string
		local char = peek()
		pos += 1

		if char == "\n" then line += 1; col = 1
		else col += 1 end

		return char
	end

	local function eof(): boolean
		return peek() == ""
	end

	local function position()
		return {
			pos = pos,
			line = line,
			col = col
		}
	end

	local function croak(msg)
		error(`{msg} ({line}:{col})`, 0)
	end

	return {
		peek = peek,
		next = next,
		eof = eof,
		croak = croak,
		pos = position
	}

end

export type String = {type: "string", s: string}
export type Number = {type: "number", s: number}
export type Identifier = {type: "identifier", s: string}
export type Keyword = {type: "keyword", s: "true" | "false" | "nil"}
export type Operator = {type: "operator", s: "="}
export type Symbol = {type: "symbol", s: "." | ":" | "[" | "]" | "{" | "}" | "(" | ")" | "," | ";"}

export type Token =
	| String
	| Number
	| Identifier
	| Keyword
	| Operator
	| Symbol

local digits = ("0123456789"):split("")
local alphabet = ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"):split("")
local symbols = ("[]{}(),;.:"):split("")

local escape_chars = {
	a = "\a",
	b = "\b",
	f = "\f",
	n = "\n",
	r = "\r",
	t = "\t",
	v = "\v",
	["\\"] = "\\",
	["\""] = "\"",
	["\'"] = "\'"
}
local keywords = {"true", "false"}

local function lex(source: string)

	local input = stream(source)

	local function is_whitespace(char: string): boolean
		return not not string.match(char, "%s")
	end

	local function is_digit(char: string): boolean
		return not not table.find(digits, char)
	end

	local function is_identifier(char: string): boolean
		return not not table.find(alphabet, char) or not not table.find(digits, char)
	end

	local function is_start_identifier(char: string): boolean
		return not not table.find(alphabet, char)
	end

	local function is_op_char(char: string): boolean
		return char == "="
	end

	local function is_punc(char: string): boolean
		return not not table.find(symbols, char)
	end

	local function read_while(predicate: (char: string) -> boolean)
		local str = ""
		while input.eof() == false and predicate(input.peek()) do
			str ..= input.next()
		end
		return str
	end

	local function skip_comment()
		read_while(function(char) return char ~= "\n" end)
	end

	local function skip_whitespace()
		read_while(is_whitespace)
	end

	local function read_string(): String
		local escaped = false
		local token = ""
		local eliminator = input.next()

		while input.eof() == false and (input.peek() ~= eliminator or escaped) do
			local char = input.next()
		
			if char == "\\" then
				escaped = true
			end

			if escaped then
				token ..= escape_chars[char] or input.croak(`cannot escape {char}`)
				escaped = false
			else
				token ..= char
			end
		end

		-- print("t", token, eliminator, input.peek())

		if input.peek() ~= eliminator then input.croak("unterminated string") end
		input.next()
		return {type = "string", s = token}
	end

	local function read_number(): Number
		local sign = 1
		if input.peek() == "-" then sign = -1; input.next() end

		local token = read_while(function(char)
			return is_digit(char) or char == "." or char == "e"
		end)

		local n = tonumber(token)

		if not n then
			input.croak(`could not read {token} as number`)
		end

		return {type = "number", s = assert(n) * sign}
	end

	local function read_identifier(): Identifier | Keyword
		local token = read_while(is_identifier)

		if table.find(keywords, token) then
			return {type = "keyword", s = token :: any}
		else
			return {type = "identifier", s = token}
		end
	end

	local function read_next(): Token
		skip_whitespace()
		local char = input.peek()

		if char == "#" then
			-- skip comment
			skip_comment()
			return read_next()
		end
		
		if char == "\"" or char == "'" then return read_string() end
		if is_digit(char) then return read_number() end
		if is_start_identifier(char) then return read_identifier() end
		if is_op_char(char) then return {type = "operator" :: "operator", s = input.next() :: any} end
		if is_punc(char) then return {type = "symbol" :: "symbol", s = input.next() :: any} end
		if char == "-" then return read_number() end

		input.croak(`cannot lex "{char}" {string.byte(char)}`)
		error("fail")
	end

	local current: {Token} = {}

	local function next()
		local token = table.remove(current, 1)
		token = if token == nil then read_next() else token
		skip_whitespace()
		return token
	end

	local function peek(n: number?)
		local n = n or 1
		while #current < n do
			table.insert(current, read_next())
		end
		return current[n]
	end

	return {

		peek = peek,
		next = next,
		eof = input.eof,
		croak = input.croak,
		pos = input.pos

	}

end

type NodeNumber = {
	type: "number",
	value: number
}

type NodeString = {
	type: "string",
	value: string
}

type NodeBoolean = {
	type: "boolean",
	value: boolean
}

type NodeVariable = {
	type: "variable",
	value: string
}

type NodeTable = {
	type: "table",
	value: {NodeExpression | NodeAssign}
}

type NodeAssign = {
	type: "assign",
	key: NodeVariable | NodeExpression,
	value: NodeExpression
}

type NodeIndex = {
	type: "index",
	value: NodeExpression,
	key: NodeExpression
}

type NodeFunctionCall = {
	type: "functioncall",
	value: NodeExpression,
	args: {NodeExpression}
}

type NodeMethodCall = {
	type: "methodcall",
	value: NodeExpression,
	args: {NodeExpression}
}

type NodeExpression =
	| NodeNumber
	| NodeString
	| NodeBoolean
	| NodeTable
	| NodeIndex
	| NodeFunctionCall
	| NodeMethodCall
	| NodeVariable

type Node =
	| NodeNumber
	| NodeString
	| NodeBoolean
	| NodeTable
	| NodeIndex
	| NodeFunctionCall
	| NodeMethodCall
	| NodeAssign
	| NodeVariable

local function parse(source: string)

	local stream = lex(source)

	local node: Node?

	local function set_node(t: Node)
		node = t
	end

	local function pop_node(): Node
		local stored = node
		node = nil
		if stored == nil then
			stream.croak("no available node")
			error("")
		end
		return stored
	end

	local function is_symbol(s: string)
		local node = stream.peek()
		return node.type == "symbol" and node.s == s
	end

	local function is_op(s: string)
		local node = stream.peek()
		return node.type == "operator" and node.s == s
	end

	local function is_keyword(s: string)
		local node = stream.peek()
		return node.type == "keyword" and node.s == s
	end

	local function skip_symbol(ch)
		if is_symbol(ch) then
			stream.next()
		else
			stream.croak(`expecting symbol: "{ch}" got "{stream.peek(1).s}"`)
			error("")
		end
	end

	local function skip_operator(ch)
		if is_op(ch) then
			stream.next()
		else
			stream.croak(`expecting op: "{ch}" got "{stream.peek().s}"`)
			error("")
		end
	end

	local function delimited(start, stop, separator: string | () -> (), parser: () -> ())
		local a = {}
		local first = true
		skip_symbol(start)
		while not stream.eof() do
			if is_symbol(stop) then break end
			if first then
				first = false
			elseif typeof(separator) == "string" then
				skip_symbol(separator)
			elseif typeof(separator) == "function" then
				separator()
			end
			if is_symbol(stop) then break end
			parser()
			table.insert(a, pop_node())
			-- print('next')
		end
		skip_symbol(stop)
		return a
	end

	local parse_functioncall
	local parse_identifier
	local parse_expression
	local parse_table
	local parse_index

	function parse_table()
		local values = delimited("{", "}", ",", function()
			
			if is_symbol("[") then
				skip_symbol("[")
				parse_expression()
				skip_symbol("]")

				local key = pop_node() :: NodeExpression
				
				skip_operator("=")
				parse_expression()

				local value = pop_node() :: NodeExpression

				set_node({
					type = "assign",
					key = key,
					value = value
				} :: NodeAssign)
			else
				if stream.peek(2).type == "operator" and stream.peek(2).s == "=" then
					parse_identifier "string"
					
					local key = pop_node() :: NodeString

					skip_operator("=")
					
					parse_expression()

					local value = pop_node() :: NodeExpression

					set_node ({
						type = "assign",
						key = key,
						value = value
					} :: NodeAssign)

				else
					parse_expression()
				end
			end

		end)

		set_node {
			type = "table",
			value = values
		}
	end

	function parse_functioncall(is_method: boolean)
		local value = pop_node()
		local arguments = delimited("(", ")", ",", function()
			parse_expression()
		end)

		set_node ({
			type = if is_method then "methodcall" else "functioncall",
			value = value,
			args = arguments
		} :: NodeFunctionCall | NodeFunctionCall)
	end

	function parse_index()
		if is_symbol(".") then
			local value = pop_node() :: NodeExpression

			skip_symbol(".")
			parse_identifier("string")

			local key = pop_node() :: NodeString

			set_node {
				type = "index",
				value = value,
				key = key
			}
		elseif is_symbol("[") then
			local value = pop_node() :: NodeExpression

			skip_symbol("[")
			parse_expression()
			skip_symbol("]")

			local key = pop_node() :: NodeExpression

			set_node {
				type = "index",
				value = value,
				key = key
			}
		elseif is_symbol(":") then
			local value = pop_node() :: NodeExpression

			skip_symbol(":")
			parse_identifier("string")

			local key = pop_node() :: NodeString

			set_node {
				type = "index",
				value = value,
				key = key
			}

			parse_functioncall(true)
		else
			stream.croak(`expected index or function call, got {stream.peek().s}`)
		end
	end

	function parse_identifier(as: "string" | "variable")
		local token = stream.next()
		if token == nil then
			stream.croak("expected identifier, got eof")
			error("")
		end

		if token.type == "identifier" then
			set_node({type = as, value = token.s} :: NodeVariable | NodeString)
		else
			stream.croak(`expected identifier, got {token.type}`)
		end
	end

	function parse_expression()
		local token = stream.peek()

		if token.type == "identifier" then
			parse_identifier "variable"

			while
				stream.eof() == false and
				(
					is_symbol(".") or
					is_symbol("[") or
					is_symbol("(") or is_symbol(":")
				)
			do
				if stream.eof() then break end
				if is_symbol("(") then
					parse_functioncall(false)
				else
					parse_index()
				end
				if stream.eof() then break end
			end
		elseif token.type == "string" then
			set_node {type = "string", value = assert(stream.next()).s :: string}
		elseif token.type == "number" then
			set_node {type = "number", value = assert(stream.next()).s :: number}
		elseif is_keyword("true") then
			set_node {type = "boolean", value = true}
			stream.next()
		elseif is_keyword("false") then
			set_node {type = "boolean", value = false}
			stream.next()
		elseif is_symbol("{") then
			parse_table()
		else
			stream.croak(`expected expression, got {token.type}" "{token.s}"`)
		end

	end

	parse_expression()

	return pop_node()

end

local tuple = {}

local lon_vars = {

	Vector3 = Vector3,
	CFrame = CFrame,
	Vector2 = Vector2,
	Color3 = Color3,
	BrickColor = BrickColor,
	Enum = Enum,

	NumberSequence = NumberSequence,
	NumberSequenceKeypoint = NumberSequenceKeypoint,
	NumberRange = NumberRange,

	ColorSequence = ColorSequence,
	ColorSequenceKeypoint = ColorSequenceKeypoint,

	Region3 = Region3,
	Rect = Rect,

	OverlapParams = function(properties)
		local params = OverlapParams.new()
		for key, value in properties do
			(params :: any)[key] = value
		end
		return params
	end,
	RaycastParams = function(properties)
		local params = RaycastParams.new()
		for key, value in properties do
			(params :: any)[key] = value
		end
		return params
	end,

	game = game,
	workspace = workspace

}

local function compile(node: Node): any

	if node.type == "number" then
		return node.value
	elseif node.type == "string" then
		return node.value
	elseif node.type == "boolean" then
		return node.value
	elseif node.type == "variable" then
		return lon_vars[node.value]
	elseif node.type == "index" then
		return compile(node.value)[compile(node.key)]
	elseif node.type == "functioncall" then
		for i = 1, #node.args do
			tuple[i] = compile(node.args[i])
		end
		return compile(node.value)(unpack(tuple, 1, #node.args))
	elseif node.type == "methodcall" then
		for i = 1, #node.args do
			tuple[i] = compile(node.args[i])
		end
		local data = compile(node.value)
		return data(data, unpack(tuple, 1, #node.args))
	elseif node.type == "table" then
		local t = {}
		local i = 0

		for _, value in node.value do
			if value.type == "assign" then
				t[compile(value.key)] = compile(value.value)
			else
				t[i + 1] = compile(value); i += 1
			end
		end

		return t
	elseif node.type == "assign" then
		error("bad ast, you cannot generate this")
	end

	return nil
end

local output

do
	local max_size = 8192
	local buf = buffer.create(1024)
	local pos = 0
	local tbs = 0
	local enable_newlines = true
	local line_length = 0
	
	local temp_input = buffer.create(1024)

	local cyclic_buffer = {}

	local function prealloc(bytes: number)
		local old_size = buffer.len(buf)

		if pos + bytes >= old_size then
			local new_size = old_size + old_size / 2
			while pos + bytes >= new_size do
				new_size = new_size + new_size / 2
			end

			local new_buf = buffer.create(new_size)
			buffer.copy(new_buf, 0, buf, 0, pos)
			buf = new_buf
		end
	end

	local function write_str(str: string)
		local old_size = buffer.len(buf)

		if pos + #str >= old_size then
			local new_size = old_size + old_size / 2
			while pos + #str >= new_size do
				new_size = new_size + new_size / 2
			end

			local new_buf = buffer.create(new_size)
			buffer.copy(new_buf, 0, buf, 0, pos)
			buf = new_buf
		end

		buffer.writestring(buf, pos, str, #str)
		pos += #str
		line_length += #str
	end

	local function write_low_prec_float(n: number)
		local s = string.format("%.7g", n)
		write_str(s)
		line_length += #s
	end

	local function char(c: string): number
		return (string.byte(c))
	end

	local function write_char(char: number)
		local old_size = buffer.len(buf)

		if pos + 1 >= old_size then
			local new_size = old_size + old_size / 2
			while pos + 1 >= new_size do
				new_size = new_size + new_size / 2
			end

			local new_buf = buffer.create(new_size)
			buffer.copy(new_buf, 0, buf, 0, pos)
			buf = new_buf
		end

		buffer.writeu8(buf, pos, char)
		line_length += 1
		pos += 1
	end

	export type Displayable = unknown-- number | string | boolean | { [Displayable]: Displayable }

	local function display_string(value: string)
		local f = string.format("%q", value)
		prealloc(#f)
		write_str(f)
	end

	local function write_line()
		if enable_newlines then
			write_char(char("\n"))
			write_str(string.rep("\t", tbs))
		else
			write_char(char(" "))
		end
	end

	local display
	local fatal_if_bad = false

	local function to_path(new: boolean, ...: unknown)
		local original = fatal_if_bad
		fatal_if_bad = true

		if new then
			local input = {}
			local len = select("#", ...)

			local old_pos = pos
			local old_tbs = tbs
			local old_buf = buf
			buf = temp_input

			for i = len, 2, -1 do
				pos = 0
				tbs = 0

				local d = len - i
				display(select(i, ...))

				input[d] = buffer.readstring(temp_input, 0, pos)
			end

			pos = old_pos
			tbs = old_tbs
			buf = old_buf

			fatal_if_bad = original
			return `new({table.concat(input, ", ")})`
		else
			local input = {}
			local len = select("#", ...)

			local old_pos = pos
			local old_tbs = tbs
			local old_buf = buf
			buf = temp_input

			for i = len, 1, -1 do
				pos = 0
				tbs = 0

				local d = len - i
				display(select(i, ...))
				input[d + 1] = `[{buffer.readstring(temp_input, 0, pos)}]`
			end

			pos = old_pos
			tbs = old_tbs
			buf = old_buf
			table.insert(input, 1, "old")

			fatal_if_bad = original
			return table.concat(input)
		end
	end

	function display(value: Displayable, ...: unknown)
		if max_size < pos then return end
		if type(value) == "number" then
			write_str(tostring(value))
		elseif type(value) == "string" then
			display_string(value)
		elseif type(value) == "boolean" then
			if value == true then
				write_str("true")
			else
				write_str("false")
			end
		elseif type(value) == "table" and not cyclic_buffer[value] then
			cyclic_buffer[value] = true
			tbs += 1
			write_char(char("{"))
			for index, value in value :: {[any]: any} do
				write_line()

				if type(index) == "string" and string.match(index, "^[a-zA-Z_][a-zA-Z0-9_]*$") then
					write_str(index)
				else
					write_char(char("["))
					local original = fatal_if_bad
					fatal_if_bad = true
					display(index)
					fatal_if_bad = original
					write_char(char("]"))
				end

				write_char(char(" "))
				write_char(char("="))
				write_char(char(" "))
				
				display(value, index, ...)
				write_char(char(","))
			end

			tbs -= 1
			write_line()
			write_char(char("}"))
		elseif type(value) == "table" and cyclic_buffer[value] then
			if fatal_if_bad then 
				write_str("*cannot display table due to cyclic dependency*")
			else
				write_str(to_path(true, ...))
			end
		elseif type(value) == "nil" then
			write_str("nil")
		-- ROBLOX DEVIATION START
		elseif typeof(value) == "BrickColor" then
			write_str("BrickColor.new(")
			write_str(value.Name)
			write_char(char(")"))
		elseif typeof(value) == "CFrame" then
			if value.Rotation == CFrame.new() then
				write_str("CFrame.new(")
				display(value.X)
				write_str(", ")
				display(value.Y)
				write_str(", ")
				display(value.Z)
				write_char(char(")"))
			else
				write_str("CFrame.fromMatrix(")
				display(value.Position)
				write_str(",\n")
				display(value.XVector)
				write_str(",\n")
				display(value.YVector)
				write_str(",\n")
				display(value.ZVector)
				write_str(",\n")
			end
		elseif typeof(value) == "EnumItem" then
			write_str(tostring(value))
		elseif typeof(value) == "Enum" then
			write_str("Enum.")
			write_str(tostring(value))
		elseif typeof(value) == "Enums" then
			write_str("Enum")
		elseif typeof(value) == "Color3" then
			write_str("Color3.fromHex(")
			display_string(value:ToHex())
			write_char(char(")"))
		elseif typeof(value) == "Vector3" then
			write_str("Vector3.new(")
			write_str(tostring(value))
			write_char(char(")"))
		elseif typeof(value) == "Vector2" then
			write_str("Vector2.new(")
			write_str(tostring(value))
			write_char(char(")"))
		elseif typeof(value) == "NumberSequence" then
			write_str("NumberSequence.new(")
			if #value.Keypoints == 2 then
				write_low_prec_float(value.Keypoints[1].Value)
				write_str(", ")
				write_low_prec_float(value.Keypoints[2].Value)
			else
				display(value.Keypoints)
			end
			write_char(char(")"))
		elseif typeof(value) == "NumberSequenceKeypoint" then
			write_str("NumberSequenceKeypoint.new(")
			write_low_prec_float(value.Time)
			write_str(", ")
			write_low_prec_float(value.Value)
			if value.Envelope > 0 then
				write_str(", ")
				write_low_prec_float(value.Envelope)
			end
			write_char(char(")"))
		elseif typeof(value) == "NumberRange" then
			write_str("NumberRange.new(")
			write_low_prec_float(value.Min)
			if value.Min ~= value.Max then
				write_str(", ")
				write_low_prec_float(value.Max)
			end
			write_char(char(")"))
		elseif typeof(value) == "ColorSequence" then
			write_str("ColorSequence.new(")
			if #value.Keypoints == 2 then
				display(value.Keypoints[1].Value)
				write_str(", ")
				display(value.Keypoints[2].Value)
			else
				display(value.Keypoints)
			end
			write_char(char(")"))
		elseif typeof(value) == "ColorSequenceKeypoint" then
			write_str("ColorSequenceKeypoint.new(")
			write_low_prec_float(value.Time)
			write_str(", ")
			display(value.Value)
			write_char(char(")"))
		elseif typeof(value) == "RaycastResult" then
			--note: since a RaycastResult can't be created, we convert it into a table
			display {
				Instance = value.Instance,
				Material = value.Material,
				Normal = value.Normal,
				Position = value.Position,
				Distance = value.Distance
			}
		elseif typeof(value) == "Region3" then
			local pos, size = value.CFrame.Position, value.Size
			local min = pos - size / 2
			local max = pos + size / 2
			write_str("Region3.new(")
			display(min)
			write_str(", ")
			display(max)
			write_char(char(")"))
		elseif typeof(value) == "Rect" then
			write_str("Rect.new(")
			write_low_prec_float(value.Min.X)
			write_str(", ")
			write_low_prec_float(value.Min.Y)
			write_str(", ")
			write_low_prec_float(value.Max.X)
			write_str(", ")
			write_low_prec_float(value.Max.Y)
			write_char(char(")"))
		elseif typeof(value) == "OverlapParams" then
			write_str("OverlapParams(")
			display({
				CollisionGroup = value.CollisionGroup,
				FilterType = value.FilterType,
				MaxParts = value.MaxParts,
				RespectCanCollide = value.RespectCanCollide,
			})
			write_char(char(")"))
		elseif typeof(value) == "RaycastParams" then
			write_str("RaycastParams(")
			display({
				CollisionGroup = value.CollisionGroup,
				FilterType = value.FilterType,
				RespectCanCollide = value.RespectCanCollide,
			})
			write_char(char(")"))
		elseif typeof(value) == "Instance" and not fatal_if_bad then
			write_str(to_path(false, ...))
		elseif typeof(value) == "Instance" and fatal_if_bad then
			write_str(value:GetFullName())
		-- ROBLOX DEVIATION END
		else
			write_str(to_path(false, ...))
		end
	end

	output = function(value: Displayable, newlines: boolean?, preview: boolean?)
		enable_newlines = if newlines ~= nil then newlines else true

		pos = 0
		tbs = 0

		table.clear(cyclic_buffer)
		if preview then fatal_if_bad = true end
		display(value)
		fatal_if_bad = false
		return buffer.readstring(buf, 0, pos)
	end
end

return {

	parse = parse,
	compile = function(node: Node, variables: {[string]: any})
		setmetatable(lon_vars, {__index = variables or nil})
		local mt = { symbol = "new" }
		local should_recurse = false

		lon_vars.new = function(...)
			should_recurse = true
			local symbol = setmetatable({ we_left_something = true, ... }, mt)
			return symbol
		end

		local nodes = compile(node)

		local function find(input: { unknown })
			local v = nodes
			for _, key in ipairs(input) do
				v = v[key]
				if v == nil then return nil end
			end
			return v
		end

		-- recurse through nodes
		local checked = {}
		local function recurse(value: unknown)
			for k, v in pairs(value) do -- use pairs so we explicitly iterate over keys and values
				if typeof(v) == "table" and getmetatable(v) == mt then
					value[k] = find(v)
				elseif typeof(v) == "table" and checked[v] then
					continue
				elseif typeof(v) == "table" then
					checked[v] = true
					recurse(v)
				end
			end
		end

		if should_recurse and typeof(nodes) == "table" then
			recurse(nodes)
		end

		return nodes
	end,
	output = output

}