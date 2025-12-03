--!strict
-- Copies all docs related files into a dist folder with all aliases resolved to relative require paths
local fs = zune.fs
local stdpath = fs.path
local process = zune.process
local alias_resolver = require("./alias_resolver")

-- stylua: ignore
local DISABLED_SCRIPT = [[
{
    "properties": {
        "Disabled": true
    }
}
]]

local text_files = { "README.md", "LICENSE" }
local allowed_extensions = { ".luau", ".json" }
local directories = { "examples", "how_to", "modules" }
local output = "studio_docs"

local function traverse(
	dir: string,
	fn: (name: string, path: string, local_path: string, metadata: Metadata) -> (),
	start_name: string?
)
	local local_name = start_name or stdpath.basename(dir)

	for _, entry in fs.entries(dir) do
		local path = stdpath.join(dir, entry.name)
		local child = fs.metadata(path)

		local local_path = stdpath.join(local_name, entry.name)
		fn(entry.name, path, local_path, child)
		if child.kind == "directory" then
			traverse(path, fn, local_path)
		end
	end
end

if fs.stat(output).kind ~= "none" then
	fs.deleteDir(output, true)
end
fs.makeDir(output)
fs.copy("src/jecs.luau", `{output}/jecs.luau`)

for _, file in text_files do
	local source = fs.readFile(file)
	local luau_source = `--[\[\n{source}\n]\]`
	local stem = fs.path.stem(file)
	fs.writeFile(`{output}/{stem}.server.luau`, luau_source)
	fs.writeFile(`{output}/{stem}.meta.json`, DISABLED_SCRIPT)
end

for _, dir in directories do
	fs.copy(dir, `{output}/{dir}`)
end

local vfs_root = alias_resolver.build_fs_tree(output)
local resolve_alias = alias_resolver.build_resolver(vfs_root, { jecs = "jecs.luau", modules = "modules" })
traverse(output, function(name, path, local_path, metadata)
	local extension = stdpath.extension(path)
	if name == "jecs.luau" or metadata.kind ~= "file" or not table.find(allowed_extensions, extension) then
		return
	end
	local_path = string.gsub(local_path, "\\", "/") -- vindovs

	local contents = fs.readFile(path)
	local lines = string.split(contents, "\n")
	for number, line in lines do
		local require_path = string.match(line, 'require%("(@[^"]+)"%)')
		if not require_path then
			continue
		end

		local resolved_path = resolve_alias(require_path, local_path)
		if not resolved_path then
			continue
		end
		lines[number] = string.gsub(line, require_path, resolved_path)
	end
	fs.writeFile(path, table.concat(lines, "\n"))
end, "")

process.run(
	"rojo",
	{ "build", "studio_docs.project.json", "-o", "studio_docs.rbxm" },
	-- Luau
	{ stdout = "inherit", stderr = "inherit" } :: any
)
