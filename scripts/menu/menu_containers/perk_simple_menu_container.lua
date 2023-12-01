-- chunkname: @scripts/menu/menu_containers/perk_simple_menu_container.lua

require("scripts/menu/menu_containers/menu_container")

PerkSimpleMenuContainer = class(PerkSimpleMenuContainer, MenuContainer)

PerkSimpleMenuContainer.init = function (self)
	PerkSimpleMenuContainer.super.init(self)
	self:set_active(true)
end

PerkSimpleMenuContainer.set_active = function (self, active)
	self._active = active
end

PerkSimpleMenuContainer.active = function (self)
	return self._active
end

PerkSimpleMenuContainer.clear = function (self)
	self._basic_textures = nil
	self._specialized_1_textures = nil
	self._specialized_2_textures = nil
end

PerkSimpleMenuContainer.set_basic_perk = function (self, perk_name)
	if perk_name then
		self._basic_textures = Perks[perk_name].ui_textures_big
	else
		self._basic_textures = nil
	end
end

PerkSimpleMenuContainer.set_specialized_perk_1 = function (self, perk_name)
	if perk_name then
		self._specialized_1_textures = Perks[perk_name].ui_textures_big
	else
		self._specialized_1_textures = nil
	end
end

PerkSimpleMenuContainer.set_specialized_perk_2 = function (self, perk_name)
	if perk_name then
		self._specialized_2_textures = Perks[perk_name].ui_textures_big
	else
		self._specialized_2_textures = nil
	end
end

PerkSimpleMenuContainer.update_size = function (self, dt, t, gui, layout_settings)
	self._width = layout_settings.texture_background_width
	self._height = (layout_settings.padding_top or 0) + layout_settings.texture_background_height
end

PerkSimpleMenuContainer.update_position = function (self, dt, t, layout_settings, x, y, z)
	self._x = x
	self._y = y
	self._z = z
end

PerkSimpleMenuContainer.render = function (self, dt, t, gui, layout_settings)
	if not self._active then
		return
	end

	local x = self._x
	local y = self._y - (layout_settings.padding_top or 0)
	local z = self._z

	self:_update_basic_perk(dt, t, gui, layout_settings, x, y, z)
	self:_update_specialized_perk_1(dt, t, gui, layout_settings, x, y, z)
	self:_update_specialized_perk_2(dt, t, gui, layout_settings, x, y, z)

	local bgr_x = self._x
	local bgr_y = math.floor(self._y + self._height - layout_settings.texture_background_height - (layout_settings.padding_top or 0))

	Gui.bitmap(gui, layout_settings.texture_background, Vector3(math.floor(bgr_x), math.floor(bgr_y), self._z + 11), Vector2(layout_settings.texture_background_width, layout_settings.texture_background_height))
end

PerkSimpleMenuContainer._update_basic_perk = function (self, dt, t, gui, layout_settings, x, y, z)
	local texture_x = math.floor(x + layout_settings.basic_texture_offset_x)
	local texture_y = math.floor(y + layout_settings.basic_texture_offset_y)
	local texture_size = Vector2(math.floor(layout_settings.basic_texture_width), math.floor(layout_settings.basic_texture_height))

	if self._basic_textures then
		local num_textures = #self._basic_textures

		for i, texture in ipairs(self._basic_textures) do
			local texture_settings = layout_settings.texture_atlas_settings[texture]
			local uv00 = Vector2(texture_settings.uv00[1], texture_settings.uv00[2])
			local uv11 = Vector2(texture_settings.uv11[1], texture_settings.uv11[2])
			local offset_z = num_textures - i

			Gui.bitmap_uv(gui, layout_settings.texture_atlas_name, uv00, uv11, Vector3(texture_x, texture_y, self._z + offset_z + 12), texture_size)
		end
	end
end

PerkSimpleMenuContainer._update_specialized_perk_1 = function (self, dt, t, gui, layout_settings, x, y, z)
	local texture_x = math.floor(x + layout_settings.specialized_1_texture_offset_x)
	local texture_y = math.floor(y + layout_settings.specialized_1_texture_offset_y)
	local texture_size = Vector2(math.floor(layout_settings.specialized_1_texture_width), math.floor(layout_settings.specialized_1_texture_height))

	if self._specialized_1_textures then
		local num_textures = #self._specialized_1_textures

		for i, texture in ipairs(self._specialized_1_textures) do
			local texture_settings = layout_settings.texture_atlas_settings[texture]
			local uv00 = Vector2(texture_settings.uv00[1], texture_settings.uv00[2])
			local uv11 = Vector2(texture_settings.uv11[1], texture_settings.uv11[2])
			local offset_z = num_textures - i

			Gui.bitmap_uv(gui, layout_settings.texture_atlas_name, uv00, uv11, Vector3(texture_x, texture_y, self._z + offset_z + 12), texture_size)
		end
	end
end

PerkSimpleMenuContainer._update_specialized_perk_2 = function (self, dt, t, gui, layout_settings, x, y, z)
	local texture_x = math.floor(x + layout_settings.specialized_2_texture_offset_x)
	local texture_y = math.floor(y + layout_settings.specialized_2_texture_offset_y)
	local texture_size = Vector2(math.floor(layout_settings.specialized_2_texture_width), math.floor(layout_settings.specialized_2_texture_height))

	if self._specialized_2_textures then
		local num_textures = #self._specialized_2_textures

		for i, texture in ipairs(self._specialized_2_textures) do
			local texture_settings = layout_settings.texture_atlas_settings[texture]
			local uv00 = Vector2(texture_settings.uv00[1], texture_settings.uv00[2])
			local uv11 = Vector2(texture_settings.uv11[1], texture_settings.uv11[2])
			local offset_z = num_textures - i

			Gui.bitmap_uv(gui, layout_settings.texture_atlas_name, uv00, uv11, Vector3(texture_x, texture_y, self._z + offset_z + 12), texture_size)
		end
	end
end

PerkSimpleMenuContainer.create_from_config = function (text)
	return PerkSimpleMenuContainer:new(text)
end
