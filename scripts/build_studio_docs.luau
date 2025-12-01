--!strict
-- Copies all docs related files into a dist folder where all `@jecs` aliases inside them are replaced with their relative require path to jecs source code
-- This script may break if there's ever a Luau module (`init.luau`) in the mix, as it just counts how deep the file is and prepends `../` to `jecs` that many times
local fs = zune.fs
local process = zune.process

local text_files = { "README.md", "LICENSE" }
local extension_whitelist = { ".luau", ".json" }
local dirs = { "examples", "how_to", "modules" }
local dist = "studio_docs"

local function traverse(dir: string, fn: (path: string, depth: number, metadata: Metadata) -> (), depth: number?)
	depth = depth or 0
	for _, entry in fs.entries(dir) do
		local path = `{dir}/{entry.name}`
		local metadata = fs.metadata(path)
		fn(path, depth, metadata)
		if entry.kind == "directory" then
			traverse(path, fn, depth + 1)
		end
	end
end

local function relativify(depth: number): string
	return string.rep("../", depth) .. "jecs"
end

if fs.stat(dist).kind ~= "none" then
	fs.deleteDir(dist, true)
end
fs.makeDir(dist)
fs.copy("src/jecs.luau", `{dist}/jecs.luau`)

for _, file in text_files do
	local source = fs.readFile(file)
	local scriptified_source = `--[\[\n{source}\n]\]`
	local stem = fs.path.stem(file)
	fs.writeFile(`{dist}/{stem}.server.luau`, scriptified_source)
	fs.writeFile(
		`{dist}/{stem}.meta.json`,
		-- stylua: ignore
		[[
{
    "properties": {
        "Disabled": true
    }
}
    ]]
	)
end

for _, dir in dirs do
	fs.copy(dir, `{dist}/{dir}`)
end

traverse(dist, function(path, depth, metadata)
	if metadata.kind ~= "file" then
		return
	end

	-- whitelist instead of blacklist
	local extension = fs.path.extension(path)
	if not table.find(extension_whitelist, extension) then
		fs.deleteFile(path)
		return
	end

	local source = fs.readFile(path)
	local relative_jecs_path = relativify(depth)
	source = string.gsub(source, "@jecs", relative_jecs_path)
	fs.writeFile(path, source)
end)

process.run(
	"rojo",
	{ "build", "studio_docs.project.json", "-o", "studio_docs.rbxm" },
	-- Luau
	{ stdout = "inherit", stderr = "inherit" } :: any
)
