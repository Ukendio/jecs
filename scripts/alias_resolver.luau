local fs = zune.fs
local stdpath = fs.path

export type FsFileNode = {
	name: string,
	kind: "file",
	parent: FsDirNode?,
}

export type FsDirNode = {
	name: string,
	kind: "dir",
	parent: FsDirNode?,
	children: { [string]: FsNode },
}

export type FsNode = FsFileNode | FsDirNode

local function build_fs_tree(path: string, parent: FsDirNode?): FsDirNode
	local children = {}
	local node = {
		name = stdpath.basename(path),
		kind = "dir",
		parent = parent,
		children = children,
	}

	for _, entry in fs.entries(path) do
		local child_path = stdpath.join(path, entry.name)
		local child_node: FsNode = if entry.kind == "directory"
			then build_fs_tree(child_path, node)
			else { name = entry.name, kind = "file", parent = node }
		children[entry.name] = child_node
	end

	return node
end

local function path_to_node(root: FsDirNode, path: string, traverse_modules: boolean?): FsNode?
	local names = string.split(path, "/")
	assert(#names > 0, `Invalid path: {path}`)

	local node = root
	for idx, name in names do
		if name == "" then
			break
		end

		if name == "." then
			continue
		end

		if name == ".." then
			local parent = node.parent
			if not parent then
				return nil
			end
			node = node.parent
			continue
		end

		local child = node.children[name]

		if not child and traverse_modules then
			child = node.children[name .. ".luau"]
			if not child then
				child = node.children["init.luau"]
				if not child then
					return nil
				end
			end
		end

		if child.kind == "file" and idx < #names then
			return nil
		end

		node = child
	end

	if traverse_modules and node.kind == "dir" then
		local possible_module = node.children["init.luau"]
		if possible_module then
			return possible_module
		end
	end

	return node
end

local function get_closest_common_ancestor(from: FsNode, to: FsNode): FsNode?
	local from_ancestors: { FsDirNode } = {}
	do
		local ancestor = from.parent
		while ancestor ~= nil do
			table.insert(from_ancestors, ancestor)
			ancestor = ancestor.parent
		end

		if #from_ancestors <= 0 then
			return nil
		end
	end

	local to_ancestor_lookup: { [FsDirNode]: true } = {}
	local to_ancestors: { FsDirNode } = {}
	do
		local ancestor = to.parent
		while ancestor ~= nil do
			to_ancestor_lookup[ancestor] = true
			table.insert(to_ancestors, ancestor)
			ancestor = ancestor.parent
		end

		if #to_ancestors <= 0 then
			return nil
		end
	end

	local closest_common_ancestor: FsDirNode? = nil
	for _, ancestor in from_ancestors do
		if to_ancestor_lookup[ancestor] then
			closest_common_ancestor = ancestor
			break
		end
	end

	return closest_common_ancestor
end

local function get_relative_module_path(from: FsFileNode, to: FsFileNode): string?
	local common_ancestor = get_closest_common_ancestor(from, to)
	if not common_ancestor then
		return nil
	end

	local path = ""
	if not from.parent then
		return nil
	end

	local traverse_from: FsNode = nil :: any
	local is_init = stdpath.stem(from.name) == "init"
	if common_ancestor == from.parent then
		path = if is_init then "@self" else "."
		traverse_from = from.parent :: FsNode
	else
		if not from.parent.parent then
			return nil
		end

		if common_ancestor == from.parent.parent then
			path = if is_init then "." else ".."
			traverse_from = from.parent.parent :: FsNode
		else
			if not from.parent.parent or not from.parent.parent.parent then
				return nil
			end

			path = if is_init then ".." else "../.."
			traverse_from = from.parent.parent.parent :: FsNode
		end
	end

	local from_ancestor = traverse_from.parent :: FsNode?
	while from_ancestor ~= nil and from_ancestor ~= common_ancestor and from_ancestor ~= common_ancestor.parent do
		path ..= "/.."
		from_ancestor = from_ancestor.parent
	end

	local to_ancestor = to.parent
	local to_stem = stdpath.stem(to.name)
	if to_stem == "init" then
		to_ancestor = assert(to_ancestor).parent
	end

	local to_ancestors: { FsNode } = {}
	while to_ancestor ~= nil and to_ancestor ~= common_ancestor do
		table.insert(to_ancestors, to_ancestor)
		to_ancestor = to_ancestor.parent
	end
	for idx = #to_ancestors, 1, -1 do
		local descendant = to_ancestors[idx]
		path ..= `/{descendant.name}`
	end

	local is_to_init = stdpath.stem(to.name) == "init"
	path ..= if is_to_init then `/{assert(to.parent).name}` else `/{to_stem}`

	return path
end

local function build_resolver(
	fs_root: FsDirNode,
	aliases: { [string]: string }
): (path: string, from: string) -> string?
	local alias_nodes = {}
	for alias, path in aliases do
		local node = path_to_node(fs_root, path)
		if not node then
			error(`Alias {alias} with path {path} cannot be resolved into a node`)
		end
		alias_nodes[alias] = node
	end

	return function(require_path: string, from: string): string?
		local alias = string.match(require_path, "^@([^/]+)")
		if not alias or alias == "self" or alias == "game" then
			return nil
		end

		if not aliases[alias] then
			error(`Unresolvable alias: {alias}`)
		end
		local alias_node = alias_nodes[alias]

		local origin_node = path_to_node(fs_root, from, true)
		if not origin_node or origin_node.kind ~= "file" then
			error(`The path {from} cannot be resolved into a node`)
		end

		local target_node: FsNode = alias_node
		local first_slash_idx = string.find(require_path, "/")
		if first_slash_idx then
			local len = #require_path
			local target_path = string.sub(require_path, first_slash_idx + 1, len)
			if #target_path + 1 ~= len then
				assert(alias_node.kind == "dir")
				target_node = assert(
					path_to_node(alias_node, target_path, true),
					`The path {require_path} cannot be resolved into a node`
				)
			elseif alias_node.kind == "dir" then
				target_node = assert(
					path_to_node(alias_node, "init.luau", true),
					`The path {require_path} cannot be resolved into a node`
				)
			end
		elseif alias_node.kind == "dir" then
			target_node = assert(
				path_to_node(alias_node, "init.luau", true),
				`The path {require_path} cannot be resolved into a node`
			)
		end
		assert(target_node.kind == "file")

		local path = get_relative_module_path(origin_node, target_node)
		assert(path, `Failed to navigate from {from} to {require_path}`)
		return path
	end
end

return {
	build_fs_tree = build_fs_tree,
	build_resolver = build_resolver,
}
