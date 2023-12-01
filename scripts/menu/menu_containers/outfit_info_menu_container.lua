-- chunkname: @scripts/menu/menu_containers/outfit_info_menu_container.lua

require("scripts/menu/menu_containers/menu_container")

OutfitInfoMenuContainer = class(OutfitInfoMenuContainer, MenuContainer)

OutfitInfoMenuContainer.init = function (self)
	OutfitInfoMenuContainer.super.init(self)

	self._outfit_viewer = OutfitMenuContainer.create_from_config()
	self._stats = {}

	self:set_disabled(true)
end

OutfitInfoMenuContainer.set_active = function (self, active)
	self._active = active
end

OutfitInfoMenuContainer.active = function (self)
	return self._active
end

OutfitInfoMenuContainer.set_disabled = function (self, disabled)
	self._disabled = disabled

	if disabled then
		for i, stat in ipairs(self._stats) do
			stat.value = 0
		end

		if self._outfit_viewer then
			self._outfit_viewer:clear()
		end
	end
end

OutfitInfoMenuContainer.load_gear = function (self, slot_name, gear_name)
	self._stats = {}

	if gear_name then
		local settings = Gear[gear_name]

		if slot_name ~= "shield" then
			self._stats[#self._stats + 1] = {
				name = L("menu_speed"),
				value = OutfitHelper.gear_property(gear_name, "speed"),
				max_value = OutfitHelper.gear_property_max("speed")
			}
			self._stats[#self._stats + 1] = {
				name = L("menu_damage"),
				value = OutfitHelper.gear_property(gear_name, "base_damage"),
				max_value = OutfitHelper.gear_property_max("base_damage")
			}
			self._stats[#self._stats + 1] = {
				name = L("menu_range"),
				value = OutfitHelper.gear_property(gear_name, "reach"),
				max_value = OutfitHelper.gear_property_max("reach")
			}
		end

		self._stats[#self._stats + 1] = {
			name = L("menu_encumbrance"),
			value = OutfitHelper.gear_property(gear_name, "encumbrance"),
			max_value = OutfitHelper.gear_property_max("encumbrance")
		}

		self._outfit_viewer:load_gear(gear_name)
		self:set_disabled(false)
	else
		if slot_name ~= "shield" then
			self._stats[#self._stats + 1] = {
				value = 0,
				max_value = 1,
				name = L("menu_speed")
			}
			self._stats[#self._stats + 1] = {
				value = 0,
				max_value = 1,
				name = L("menu_damage")
			}
			self._stats[#self._stats + 1] = {
				value = 0,
				max_value = 1,
				name = L("menu_range")
			}
		end

		self._stats[#self._stats + 1] = {
			value = 0,
			max_value = 1,
			name = L("menu_encumbrance")
		}

		self._outfit_viewer:clear()
		self:set_disabled(true)
	end
end

OutfitInfoMenuContainer.load_armour = function (self, armour_name)
	if armour_name then
		local settings = Armours[armour_name]

		self._stats = {
			{
				name = L("menu_absorption"),
				value = settings.absorption_value,
				max_value = OutfitHelper.armour_property_max("absorption_value")
			},
			{
				name = L("menu_encumbrance"),
				value = settings.encumbrance,
				max_value = OutfitHelper.armour_property_max("encumbrance")
			}
		}

		self._outfit_viewer:load_armour(armour_name)
		self:set_disabled(false)
	else
		self._stats = {
			{
				value = 0,
				max_value = 1,
				name = L("menu_absorption")
			},
			{
				value = 0,
				max_value = 1,
				name = L("menu_encumbrance")
			}
		}

		self._outfit_viewer:clear()
		self:set_disabled(true)
	end
end

OutfitInfoMenuContainer.load_helmet = function (self, helmet_name)
	if helmet_name then
		local settings = Helmets[helmet_name]

		self._stats = {
			{
				name = L("menu_absorption"),
				value = settings.absorption_value,
				max_value = OutfitHelper.helmet_property_max("absorption_value")
			},
			{
				name = L("menu_encumbrance"),
				value = settings.encumbrance,
				max_value = OutfitHelper.helmet_property_max("encumbrance")
			}
		}

		self._outfit_viewer:load_helmet(helmet_name)
		self:set_disabled(false)
	else
		self._stats = {
			{
				value = 0,
				max_value = 1,
				name = L("menu_absorption")
			},
			{
				value = 0,
				max_value = 1,
				name = L("menu_encumbrance")
			}
		}

		self._outfit_viewer:clear()
		self:set_disabled(true)
	end
end

OutfitInfoMenuContainer.load_mount = function (self, mount_name)
	if mount_name then
		local settings = MountProfiles[mount_name]

		self._stats = {
			{
				name = L("menu_absorption"),
				value = settings.absorption_value,
				max_value = OutfitHelper.mount_property_max("absorption_value")
			},
			{
				name = L("menu_acceleration"),
				value = settings.cruise_control_accelerate_speed,
				max_value = OutfitHelper.mount_property_max("cruise_control_accelerate_speed")
			},
			{
				name = L("menu_stamina"),
				value = settings.max_charge_stamina,
				max_value = OutfitHelper.mount_property_max("max_charge_stamina")
			}
		}

		self._outfit_viewer:load_mount(mount_name)
		self:set_disabled(false)
	else
		self._stats = {
			{
				value = 0,
				max_value = 1,
				name = L("menu_absorption")
			},
			{
				value = 0,
				max_value = 1,
				name = L("menu_acceleration")
			},
			{
				value = 0,
				max_value = 1,
				name = L("menu_stamina")
			}
		}

		self._outfit_viewer:clear()
		self:set_disabled(true)
	end
end

OutfitInfoMenuContainer.update_size = function (self, dt, t, gui, layout_settings)
	if not self._active then
		return
	end

	self._outfit_viewer:update_size(dt, t, gui, layout_settings.outfit_viewer)

	self._width = layout_settings.width

	local height = layout_settings.padding_top + layout_settings.outfit_viewer.height + layout_settings.padding_bottom

	if self._stats then
		height = height + math.abs(layout_settings.text_start_offset_y)
		height = height + #self._stats * math.abs(layout_settings.text_offset_y) + #self._stats * math.abs(layout_settings.bar_offset_y)
	end

	self._height = height
end

OutfitInfoMenuContainer.update_position = function (self, dt, t, layout_settings, x, y, z)
	if not self._active then
		return
	end

	self._x = x
	self._y = y
	self._z = z
	self._outfit_viewer_x = x + self._width / 2 - layout_settings.outfit_viewer.width / 2
	self._outfit_viewer_y = y + self._height - layout_settings.outfit_viewer.height - (layout_settings.padding_top or 0)

	self._outfit_viewer:update_position(dt, t, layout_settings.outfit_viewer, self._outfit_viewer_x, self._outfit_viewer_y, z)
end

OutfitInfoMenuContainer.render = function (self, dt, t, gui, layout_settings)
	if not self._active then
		return
	end

	self._outfit_viewer:render(dt, t, gui, layout_settings.outfit_viewer)

	local stats_x = self._outfit_viewer_x
	local stats_y = self._outfit_viewer_y + layout_settings.text_start_offset_y
	local stats_text_c = layout_settings.text_color
	local stats_text_color = self._disabled and Color(100, stats_text_c[2], stats_text_c[3], stats_text_c[4]) or Color(stats_text_c[1], stats_text_c[2], stats_text_c[3], stats_text_c[4])
	local stats_bar_color = self._disabled and Color(100, 255, 255, 255) or Color(255, 255, 255, 255)
	local font = layout_settings.font and layout_settings.font.font or MenuSettings.fonts.menu_font.font
	local font_material = layout_settings.font and layout_settings.font.material or MenuSettings.fonts.menu_font.material
	local shadow_color_table = layout_settings.drop_shadow_color
	local shadow_color = shadow_color_table and Color(shadow_color_table[1], shadow_color_table[2], shadow_color_table[3], shadow_color_table[4])
	local shadow_offset = layout_settings.drop_shadow_offset and Vector2(layout_settings.drop_shadow_offset[1], layout_settings.drop_shadow_offset[2])

	for _, stat_config in ipairs(self._stats) do
		stats_y = stats_y + layout_settings.text_offset_y

		ScriptGUI.text(gui, stat_config.name, font, layout_settings.font_size, font_material, Vector3(math.floor(stats_x), math.floor(stats_y), self._z + 1), stats_text_color, shadow_color, shadow_offset)

		stats_y = stats_y + layout_settings.bar_offset_y

		Gui.bitmap(gui, layout_settings.bar_background_texture, Vector3(math.floor(stats_x), math.floor(stats_y), self._z + 1), Vector2(math.floor(layout_settings.bar_width), layout_settings.bar_background_texture_height), stats_bar_color)

		local bar_width = math.floor(layout_settings.bar_width * (stat_config.value / stat_config.max_value))

		Gui.bitmap(gui, layout_settings.bar_filling_texture, Vector3(math.floor(stats_x), math.floor(stats_y), self._z + 2), Vector2(bar_width, layout_settings.bar_filling_texture_height), stats_bar_color)

		if not self._disabled then
			-- Nothing
		end
	end
end

OutfitInfoMenuContainer.create_from_config = function ()
	return OutfitInfoMenuContainer:new()
end
