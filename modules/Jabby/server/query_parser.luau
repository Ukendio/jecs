--!strict

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

export type Position = {
	line: number,
	pos: number,
	col: number
}

export type String = {type: "string", s: string}
export type Number = {type: "number", s: number}
export type Identifier = {type: "identifier", s: string}
export type Operator = {type: "operator", s: "#" | "!" | "*" | "$"}
export type Symbol = {type: "symbol", s: "(" | ")" | ";" | ","}
export type EOF = {type: "eof", s: "eof"}

export type Token =
	String
	| Number
	| Identifier
	| Symbol
	| Operator
	| EOF


export type Stream = {
	next: () -> Token,
	peek: (n: number?) -> Token,
	eof: () -> boolean,
	croak: (msg: string) -> (),
	pos: () -> Position
}

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

local function lex(source: string): Stream
	
	local input = stream(source)

	local function is_whitespace(char: string)
		return not not string.match(char, "[\t ]")
	end

	local function is_digit(char: string)
		return not not (string.match(char, "%d"))
	end
	
	local function is_start_identifier(char: string)
		return not not string.match(char, "[%a_]")
	end

	local function is_identifier(char: string)
		return not not string.match(char, "[%a_:%.]")
	end
	
	local function is_op_char(char: string)
		return char == "#" or char == "!" or char == "*" or char == "$"
	end

	local function is_punc(char: string)
		return not not string.match(char, "[%(%);,]")
	end

	local function read_while(predicate: (char: string) -> boolean)
		local str = ""
		while input.eof() == false and predicate(input.peek()) do
			str ..= input.next()
		end
		return str
	end

	local function skip_whitespace()
		read_while(is_whitespace)
	end

	local function read_string(): String
		local escaped = false
		local token = ""
		local eliminator = input.next()
		local from = input.pos()

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

		local to = input.pos()

		-- print("t", token, eliminator, input.peek())

		if input.peek() ~= eliminator then input.croak("unterminated string") end
		input.next()
		return {type = "string", s = token, from = from, to = to}
	end

	local function read_number(): Number
		local decimal_pointer = false
		local from = input.pos()
		local token = read_while(function(char)
			if decimal_pointer and char == "." then return false end
			if char == "." then decimal_pointer = true end
			return is_digit(char)
		end)
		local to = input.pos()

		local n = tonumber(token)

		if not n then
			input.croak(`could not read {token} as number`)
		end

		return {type = "number", s = assert(n), from = from, to = to}
	end

	local function read_identifier(): Identifier
		local from = input.pos()
		local token = read_while(is_identifier)
		local to = input.pos()

		-- if table.find(keywords, token) then
		-- 	return {type = "keyword", s = token :: any, from = from, to = to}
		-- else
		return {type = "identifier", s = token, from = from, to = to}
		-- end
	end
	
	local function read_next(): Token
		skip_whitespace()
		if input.eof() then return {type = "eof", s = "eof"} end

		local char = input.peek()

		if char == "\"" or char == "'" then return read_string() end
		if is_digit(char) then return read_number() end
		if is_start_identifier(char) then return read_identifier() end
		if is_op_char(char) then return {type = "operator", s = input.next() :: any} end
		if is_punc(char) then return {type = "symbol", s = input.next() :: any} end

		input.croak(`cannot lex {char}`)
		error("fail")
	end

	local current: {Token} = {}

	local function next()
		local token = table.remove(current, 1)
		return if token == nil then read_next() else token
	end

	local function peek(n: number?)
		local n = n or 1
		while #current < n do
			table.insert(current, read_next())
		end
		return current[n]
	end

	local function eof()
		return peek().type == "eof"
	end

	return {

		peek = peek,
		next = next,
		eof = eof,
		croak = input.croak,
		pos = input.pos

	}
end

type Wildcard = {
	type: "Wildcard",
	name: "*"
}

export type Value = {
	type: "Name",
	name: string
} | {
	type: "Entity",
	entity: number
}

export type PureComponent = {
	type: "Component",
	query: boolean,
	exclude: boolean,
	value: Value,
}

export type Relationship = {
	type: "Relationship",
	query: boolean,
	exclude: boolean,
	left: PureComponent | Wildcard,
	right: PureComponent | Wildcard
}

type Component = Relationship | PureComponent | Wildcard

local function parse(input: string): {PureComponent | Relationship}
	local lexer = lex(input)

	local result: {PureComponent | Relationship} = {}

	local should_query = true
	local should_exclude = false
	local should_relationship = false
	local interpret_pointer = false
	local components: {Component} = {}

	while true do
		local symbol = lexer.peek()
		-- print2(symbol)
		if symbol.type == "eof" then
			break
		elseif interpret_pointer or symbol.type == "number" then
			if not interpret_pointer then
				lexer.croak("expected $")
			elseif symbol.type ~= "number" then
				lexer.croak("expected number")
				error("")
			end

			table.insert(components, {
				type = "Component",
				query = should_query,
				exclude = should_exclude,
				value = {type = "Entity", entity = tonumber(lexer.next().s) :: number}
			})

			should_query = if should_relationship then should_query else true
			should_exclude = if should_relationship then should_exclude else false
			interpret_pointer = false
			if lexer.peek().type ~= "symbol" and lexer.peek().type ~= "eof" then lexer.croak("expected symbol or eof after identifier") end
		elseif symbol.type == "operator" then
			if symbol.s == "#" then
				if should_relationship then lexer.croak("cannot tag inside relationship") end
				should_query = false
				lexer.next()
			elseif symbol.s == "!" then
				if should_relationship then lexer.croak("cannot exclude in relationship") end
				should_exclude = true
				should_query = false
				lexer.next()
			elseif symbol.s == "$" then
				interpret_pointer = true
				lexer.next()
			elseif symbol.s == "*" then
				if not should_relationship then lexer.croak("cannot use wildcards outside relationship") end
				table.insert(components, {
					type = "Wildcard",
					name = "*"
				})
				lexer.next()
			end
		elseif symbol.type == "symbol" then
			if symbol.s == "(" then
				if should_relationship == true then lexer.croak("relationship within relationship") end
				should_relationship = true
				lexer.next()
			elseif symbol.s == ")" then
				if should_relationship == false then lexer.croak("missing (") end
				if #components == 2 then
					local right = table.remove(components) :: Component
					local left = table.remove(components) :: Component

					if left.type == "Wildcard" and right.type == "Wildcard" then
						lexer.croak("both components are wildcards")
					end

					components = {{
						type = "Relationship",
						query = should_query,
						exclude = should_exclude,
						left = left :: any,
						right = right :: any
					}}

					should_query = true
					should_exclude = false
					should_relationship = false
					lexer.next()
				else
					lexer.croak(`expected 2 components, got {#components}`)
				end
			elseif symbol.s == "," or symbol.s == ";" then
				if should_relationship then
					lexer.next()
					continue
				end

				local ctype = table.remove(components)
				if ctype == nil then
					lexer.croak("no component provided")
					error("")
				end

				table.insert(result, ctype :: any)

				should_query = true
				should_exclude = false
				lexer.next()
			end
		elseif symbol.type == "identifier" then
			table.insert(components, {
				type = "Component",
				query = should_query,
				exclude = should_exclude,
				value = {type = "Name", name = lexer.next().s :: string}
			})

			should_query = if should_relationship then should_query else true
			should_exclude = if should_relationship then should_exclude else false
			if lexer.peek().type ~= "symbol" and lexer.peek().type ~= "eof" then lexer.croak("expected symbol or eof after identifier") end
		elseif symbol.type == "string" then
			table.insert(components, {
				type = "Component",
				query = should_query,
				exclude = should_exclude,
				value = {type = "Name", name = lexer.next().s :: string}
			})
			should_query = if should_relationship then should_query else true
			should_exclude = if should_relationship then should_exclude else false
			if lexer.peek().type ~= "symbol" and lexer.peek().type ~= "eof" then lexer.croak("expected symbol or eof after string") end
		end
	end

	table.insert(result, table.remove(components) :: any)

	return result
end

return parse