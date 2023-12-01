-- chunkname: @scripts/menu/menu_items/spawn_map_menu_item.lua

require("scripts/menu/menu_items/menu_item")

SpawnMapMenuItem = class(SpawnMapMenuItem, MenuItem)

SpawnMapMenuItem.init = function (self, config, world)
	SpawnMapMenuItem.super.init(self, config, world)

	local level_settings = LevelHelper:current_level_settings()

	self._texture = level_settings.minimap_texture or "map_not_found"
end

SpawnMapMenuItem.is_mouse_inside = function (self, m_x, m_y)
	return false
end

SpawnMapMenuItem.update_size = function (self, dt, t, gui, layout_settings)
	self._width = layout_settings.width
	self._height = layout_settings.height
end

SpawnMapMenuItem.update_position = function (self, dt, t, layout_settings, x, y, z)
	self._x = x
	self._y = y
	self._z = z
end

SpawnMapMenuItem.render = function (self, dt, t, gui, layout_settings)
	Gui.bitmap(gui, self._texture, Vector3(math.floor(self._x), math.floor(self._y), self._z), Vector2(self._width, self._height))
end

SpawnMapMenuItem.create_from_config = function (compiler_data, config, callback_object)
	local config = {
		disabled = true,
		type = "spawn_map",
		callback_object = callback_object,
		layout_settings = config.layout_settings
	}

	return SpawnMapMenuItem:new(config, compiler_data.world)
end
