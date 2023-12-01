-- chunkname: @scripts/menu/menu_containers/outfit_menu_container.lua

require("scripts/menu/menu_containers/menu_container")

OutfitMenuContainer = class(OutfitMenuContainer, MenuContainer)

OutfitMenuContainer.init = function (self, world_name, viewport_name)
	OutfitMenuContainer.super.init(self, world_name)

	self._outfit_texture = nil
	self._attachment_icons = nil
end

OutfitMenuContainer.clear = function (self)
	self._outfit_texture = nil
	self._attachment_icons = nil
end

OutfitMenuContainer.load_gear = function (self, gear_name)
	self._outfit_texture = Gear[gear_name].ui_texture
end

OutfitMenuContainer.load_gear_attachments = function (self, gear_name, player_profile)
	local gear_settings = Gear[gear_name]
	local profile_gear = ProfileHelper:find_gear_by_name(player_profile.gear, gear_name)
	local icons = {}

	for _, icon_categories in ipairs(gear_settings.ui_small_attachment_icons) do
		local icon

		for _, icon_category in ipairs(icon_categories) do
			local attachment_names = profile_gear.attachments[icon_category]

			if attachment_names then
				local textures = OutfitHelper.small_attachment_textures(gear_name, icon_category, attachment_names[1])

				for i = #textures, 1, -1 do
					icon = icon or {}
					icon[#icon + 1] = textures[i]
				end
			end
		end

		icons[#icons + 1] = icon
	end

	self._attachment_icons = icons
end

OutfitMenuContainer.load_helmet = function (self, helmet_name)
	self._outfit_texture = Helmets[helmet_name].ui_texture
end

OutfitMenuContainer.load_armour = function (self, armour_name)
	self._outfit_texture = Armours[armour_name].ui_texture
end

OutfitMenuContainer.load_mount = function (self, mount_name)
	self._outfit_texture = MountProfiles[mount_name].ui_texture
end

OutfitMenuContainer.update_size = function (self, dt, t, gui, layout_settings)
	self._width = layout_settings.width
	self._height = layout_settings.height
end

OutfitMenuContainer.update_position = function (self, dt, t, layout_settings, x, y, z)
	self._x = x
	self._y = y
	self._z = z
end

OutfitMenuContainer.render = function (self, dt, t, gui, layout_settings)
	self:_render_outfit_textures(dt, t, gui, layout_settings)
	self:_render_attachment_icons(dt, t, gui, layout_settings)
end

OutfitMenuContainer._render_attachment_icons = function (self, dt, t, gui, layout_settings)
	if self._attachment_icons then
		local texture_x = math.floor(self._x + layout_settings.attachment_texture_offset_x)
		local texture_y = math.floor(self._y + layout_settings.attachment_texture_offset_y)
		local texture_size = Vector2(layout_settings.attachment_texture_size, layout_settings.attachment_texture_size)

		for i, textures in ipairs(self._attachment_icons) do
			local num_textures = #textures

			for i, texture in ipairs(textures) do
				local texture_settings = layout_settings.attachment_texture_atlas_settings[texture]
				local uv00 = Vector2(texture_settings.uv00[1], texture_settings.uv00[2])
				local uv11 = Vector2(texture_settings.uv11[1], texture_settings.uv11[2])

				Gui.bitmap_uv(gui, layout_settings.attachment_texture_atlas_name, uv00, uv11, Vector3(texture_x, texture_y, self._z + i + 14), texture_size)
			end

			texture_x = texture_x + layout_settings.attachment_texture_spacing_x + layout_settings.attachment_texture_size
		end
	end
end

OutfitMenuContainer._render_outfit_textures = function (self, dt, t, gui, layout_settings)
	if self._outfit_texture then
		local texture_x = math.floor(self._x + layout_settings.outfit_texture_offset_x)
		local texture_y = math.floor(self._y + layout_settings.outfit_texture_offset_y)
		local texture_size = Vector2(layout_settings.outfit_texture_width, layout_settings.outfit_texture_height)
		local texture_settings = layout_settings.outfit_texture_atlas_settings[self._outfit_texture]
		local uv00 = Vector2(texture_settings.uv00[1], texture_settings.uv00[2])
		local uv11 = Vector2(texture_settings.uv11[1], texture_settings.uv11[2])

		Gui.bitmap_uv(gui, layout_settings.outfit_texture_atlas_name, uv00, uv11, Vector3(texture_x, texture_y, self._z + 12), texture_size)
		Gui.bitmap(gui, layout_settings.outfit_texture_overlay, Vector3(texture_x, texture_y, self._z + 13), texture_size)
	end

	local bgr_texture_size = Vector2(layout_settings.outfit_texture_background_width, layout_settings.outfit_texture_background_height)

	Gui.bitmap(gui, layout_settings.outfit_texture_background, Vector3(math.floor(self._x), math.floor(self._y), self._z + 11), bgr_texture_size)
end

OutfitMenuContainer.create_from_config = function ()
	return OutfitMenuContainer:new()
end
