-- chunkname: @scripts/menu/menu_items/spawn_area_marker_menu_item.lua

require("scripts/menu/menu_items/menu_item")

SpawnAreaMarkerMenuItem = class(SpawnAreaMarkerMenuItem, MenuItem)

SpawnAreaMarkerMenuItem.init = function (self, config, world)
	SpawnAreaMarkerMenuItem.super.init(self, config, world)

	self._position = config.position

	self:set_selected(false)
end

SpawnAreaMarkerMenuItem.on_select = function (self, ignore_sound)
	self:set_selected(true)
	TextMenuItem.super.on_select(self, ignore_sound)
end

SpawnAreaMarkerMenuItem.on_deselect = function (self)
	self:set_selected(false)
end

SpawnAreaMarkerMenuItem.set_selected = function (self, selected)
	self._selected = selected
end

SpawnAreaMarkerMenuItem.update_size = function (self, dt, t, gui, layout_settings)
	self._width = layout_settings.spawn_area_texture_width
	self._height = layout_settings.spawn_area_texture_height
end

SpawnAreaMarkerMenuItem.update_position = function (self, dt, t, layout_settings, x, y, z, minimap_props)
	local origo = minimap_props.origo:unbox()
	local pos = self._position:unbox()
	local map_x, map_y = MenuHelper.calculate_minimap_position(pos, minimap_props)

	self._x = x + map_x
	self._y = y + map_y
	self._z = z
end

SpawnAreaMarkerMenuItem.render = function (self, dt, t, gui, layout_settings)
	local spawn_area_texture = self._highlighted and layout_settings.spawn_area_texture_highlighted or layout_settings.spawn_area_texture
	local x = self._x + self._width / 2 - layout_settings.spawn_area_texture_width / 2
	local y = self._y + self._height / 2 - layout_settings.spawn_area_texture_height / 2
	local color = self._highlighted and Color(255, 255, 255, 255) or Color(200, 255, 255, 255)

	Gui.bitmap(gui, spawn_area_texture, Vector3(math.floor(x), math.floor(y), self._z or 1), Vector2(self._width, self._height), color)

	local x = self._x + self._width / 2 - layout_settings.spawn_target_texture_width / 2
	local y = self._y + self._height / 2 - layout_settings.spawn_target_texture_height / 2

	if self.config.selected_spawn_target then
		local anim_offset_y = math.abs(layout_settings.spawn_target_anim_amplitude * math.sin(t * math.pi * layout_settings.spawn_target_anim_speed))

		self._anim_offset_y = layout_settings.spawn_target_offset_y + anim_offset_y
	else
		self._anim_offset_y = layout_settings.spawn_target_offset_y
	end

	Gui.bitmap(gui, layout_settings.spawn_target_texture, Vector3(math.floor(x), math.floor(y) + self._anim_offset_y, self._z + 1), Vector2(layout_settings.spawn_target_texture_width, layout_settings.spawn_target_texture_height), color)
end

SpawnAreaMarkerMenuItem.create_from_config = function (compiler_data, config, callback_object)
	local config = {
		selected_spawn_target = false,
		type = "area_marker",
		name = config.name,
		callback_object = callback_object,
		on_select = config.on_select,
		on_select_args = config.on_select_args,
		position = config.position,
		layout_settings = config.layout_settings,
		parent_page = config.parent_page,
		sounds = config.parent_page.config.sounds.items.spawn_area_marker
	}

	return SpawnAreaMarkerMenuItem:new(config, compiler_data.world)
end
