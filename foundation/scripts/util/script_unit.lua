-- chunkname: @foundation/scripts/util/script_unit.lua

ScriptUnit = ScriptUnit or {}

ScriptUnit.extension_input = function (unit, system_name)
	local extension_input = Unit.get_data(unit, system_name, "input")

	fassert(extension_input, "No extension input found belonging to system %q for unit %q", system_name, unit)

	return extension_input
end

ScriptUnit.has_extension_input = function (unit, system_name)
	return Unit.has_data(unit, system_name, "input")
end

ScriptUnit.extension = function (unit, system_name)
	local extension = Unit.get_data(unit, system_name, "extension")

	fassert(extension, "No extension found belonging to system %q for unit %q", system_name, unit)

	return extension
end

ScriptUnit.has_extension = function (unit, system_name)
	return Unit.has_data(unit, system_name, "extension")
end

ScriptUnit.add_extension = function (world, unit, extension_name, ...)
	local extension_class = rawget(_G, extension_name)

	fassert(extension_class, "No class found for extension with name %q", extension_name)

	local extension = extension_class:new(world, unit, ...)
	local system_name = extension.SYSTEM

	fassert(system_name, "%q.SYSTEM is not set", extension_name)
	fassert(not ScriptUnit.has_extension(unit, system_name), "An extension already exists for system %q belonging to unit %s", system_name, unit)
	Unit.set_data(unit, system_name, "input", {})
	Unit.set_data(unit, system_name, "extension", extension)

	local registered_systems = Unit.get_data(unit, "systems") or {}

	table.insert(registered_systems, system_name)
	Unit.set_data(unit, "systems", registered_systems)
end

ScriptUnit.remove_extension = function (unit, system_name)
	local extension = ScriptUnit.extension(unit, system_name)

	fassert(extension.destroy, "[ScriptUnit] Extension for system %s for unit %s missing a destroy function.", system_name, unit)
	extension:destroy()
	Unit.set_data(unit, system_name, "input", nil)
	Unit.set_data(unit, system_name, "extension", nil)
end

ScriptUnit.remove_extensions = function (unit)
	local registered_systems = Unit.get_data(unit, "systems")

	for i = #registered_systems, 1, -1 do
		local system_name = registered_systems[i]

		ScriptUnit.remove_extension(unit, system_name)
	end
end

ScriptUnit.extension_definitions = function (unit)
	local extensions = {}
	local i = 0

	while Unit.has_data(unit, "extensions", i) do
		local class_name = Unit.get_data(unit, "extensions", i)

		i = i + 1
		extensions[i] = class_name
	end

	return extensions
end

ScriptUnit.save_scene_graph = function (unit)
	local link_table = {}

	for node_index = 0, Unit.num_scene_graph_items(unit) - 1 do
		local parent_node = Unit.scene_graph_parent(unit, node_index)
		local local_pose = Matrix4x4Box(Unit.local_pose(unit, node_index))

		link_table[node_index] = {
			parent = parent_node,
			local_pose = local_pose
		}
	end

	return link_table
end

ScriptUnit.restore_scene_graph = function (unit, link_table)
	for i, link in ipairs(link_table) do
		if link.parent then
			Unit.scene_graph_link(unit, i, link.parent)
			Unit.set_local_pose(unit, i, link.local_pose:unbox())
		end
	end
end
