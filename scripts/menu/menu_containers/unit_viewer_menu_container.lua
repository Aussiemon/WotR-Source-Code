-- chunkname: @scripts/menu/menu_containers/unit_viewer_menu_container.lua

require("scripts/menu/menu_containers/menu_container")

UnitViewerMenuContainer = class(UnitViewerMenuContainer, MenuContainer)

UnitViewerMenuContainer.init = function (self, world_name)
	UnitViewerMenuContainer.super.init(self)

	self._world_name = world_name
	self._units = {}
end

UnitViewerMenuContainer.update_size = function (self, dt, t, gui, layout_settings)
	local res_width, res_height = Gui.resolution()

	self._width = layout_settings.width or res_width
	self._height = layout_settings.height or res_height
end

UnitViewerMenuContainer.update_position = function (self, dt, t, layout_settings, x, y)
	self._x = x
	self._y = y
end

UnitViewerMenuContainer.render = function (self, dt, t, gui, layout_settings)
	return
end

UnitViewerMenuContainer.destroy = function (self)
	if self._current_level then
		local world = Managers.world:world(self._world_name)

		World.destroy_level(world, self._current_level)

		self._current_level = nil
		self._current_level_name = nil
	end
end

UnitViewerMenuContainer.load_level = function (self, level_name)
	if self._current_level_name ~= level_name then
		local world = Managers.world:world(self._world_name)

		if self._current_level then
			World.destroy_level(world, self._current_level)
		end

		self._current_level = ScriptWorld.load_level(world, level_name)

		Level.spawn_background(self._current_level)

		self._current_level_name = level_name
	end
end

UnitViewerMenuContainer.spawn_unit = function (self, parent_name, name, spawn_config, meta_data)
	if self._units[name] then
		self:remove_unit(name)
	end

	local position = spawn_config.position or Vector3(0, 0, 0)
	local rotation = spawn_config.rotation or Quaternion.identity()
	local parent = self._units[parent_name]
	local world = Managers.world:world(self._world_name)

	self._units[name] = UnitViewerUnit:new(world, name, parent, spawn_config.unit_name, spawn_config.attachment_node_linking, position, rotation, spawn_config.material_variation, callback(self, "cb_unit_destroyed"), meta_data)

	if parent then
		for _, anim_event in ipairs(spawn_config.animation_events) do
			if anim_event ~= "" then
				Unit.animation_event(parent:unit(), anim_event)
			end
		end
	end
end

UnitViewerMenuContainer.unit = function (self, name)
	if self._units[name] then
		return self._units[name]:unit()
	end
end

UnitViewerMenuContainer.unit_meta_data = function (self, unit_name, data_key)
	if self._units[unit_name] then
		return self._units[unit_name]:meta_data(data_key)
	end
end

UnitViewerMenuContainer.set_unit_visibility = function (self, name, group, visibility)
	self._units[name]:set_visibility(group, visibility)
end

UnitViewerMenuContainer.set_unit_position = function (self, name, position, node_index)
	self._units[name]:set_position(position, node_index)
end

UnitViewerMenuContainer.set_unit_rotation = function (self, name, rotation, node_index)
	self._units[name]:set_rotation(rotation, node_index)
end

UnitViewerMenuContainer.remove_unit = function (self, name)
	if self._units[name] then
		self._units[name]:destroy()
	end
end

UnitViewerMenuContainer.cb_unit_destroyed = function (self, name)
	self._units[name] = nil
end

UnitViewerMenuContainer.create_from_config = function (world_name)
	return UnitViewerMenuContainer:new(world_name)
end

UnitViewerUnit = class(UnitViewerUnit)

UnitViewerUnit.init = function (self, world, name, parent, unit, attachment_node_linking, position, rotation, material_variation, cb_destroyed, meta_data)
	self._world = world
	self._name = name
	self._parent = parent
	self._children = {}
	self._cb_destroyed = cb_destroyed
	self._unit = World.spawn_unit(self._world, unit, position, rotation)
	self._meta_data = meta_data

	if parent then
		self._parent:add_child(name, self)
		self:_link_to_parent(attachment_node_linking)
	end

	if material_variation then
		Unit.set_material_variation(self._unit, material_variation)
	end
end

UnitViewerUnit._link_to_parent = function (self, attachment_node_linking)
	local unit = self._unit
	local parent_unit = self._parent:unit()

	for i, attachment_nodes in ipairs(attachment_node_linking) do
		local source_node = attachment_nodes.source
		local target_node = attachment_nodes.target
		local source_node_index = type(source_node) == "string" and Unit.node(parent_unit, source_node) or source_node
		local target_node_index = type(target_node) == "string" and Unit.node(unit, target_node) or target_node

		World.link_unit(self._world, unit, target_node_index, parent_unit, source_node_index)
	end
end

UnitViewerUnit.add_child = function (self, name, child)
	self._children[name] = child
end

UnitViewerUnit.remove_child = function (self, name)
	self._children[name] = nil
end

UnitViewerUnit.unit = function (self)
	return self._unit
end

UnitViewerUnit.set_visibility = function (self, group, visibility)
	Unit.set_visibility(self._unit, group, visibility)
end

UnitViewerUnit.set_position = function (self, position, node_index)
	Unit.set_local_position(self._unit, node_index or 0, position)
end

UnitViewerUnit.set_rotation = function (self, rotation, node_index)
	Unit.set_local_rotation(self._unit, node_index or 0, rotation)
end

UnitViewerUnit.meta_data = function (self, key)
	return self._meta_data[key]
end

UnitViewerUnit.destroy = function (self)
	for name, child in pairs(self._children) do
		child:destroy()
	end

	if self._parent then
		self._parent:remove_child(self._name)
	end

	World.destroy_unit(self._world, self._unit)

	self._unit = nil

	self._cb_destroyed(self._name)
end
