return {
	white_underline = function(s: any)
		return `\27[1;4m{s}\27[0m`
	end,

	white = function(s: any)
		return `\27[37;1m{s}\27[0m`
	end,

	green = function(s: any)
		return `\27[32;1m{s}\27[0m`
	end,

	red = function(s: any)
		return `\27[31;1m{s}\27[0m`
	end,

	yellow = function(s: any)
		return `\27[33;1m{s}\27[0m`
	end,

	red_highlight = function(s: any)
		return `\27[41;1;30m{s}\27[0m`
	end,

	green_highlight = function(s: any)
		return `\27[42;1;30m{s}\27[0m`
	end,

	gray = function(s: any)
		return `\27[30;1m{s}\27[0m`
	end,
}
