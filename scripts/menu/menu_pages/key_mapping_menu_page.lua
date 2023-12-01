﻿-- chunkname: @scripts/menu/menu_pages/key_mapping_menu_page.lua

KeyMappingMenuPage = class(KeyMappingMenuPage, MainMenuPage)

KeyMappingMenuPage.init = function (self, config, item_groups, world)
	KeyMappingMenuPage.super.init(self, config, item_groups, world)
end

KeyMappingMenuPage.on_enter = function (self)
	KeyMappingMenuPage.super.on_enter(self)

	self._just_entered = true
end

KeyMappingMenuPage.on_exit = function (self)
	self._key_item:on_deselect()
end

KeyMappingMenuPage.set_key_item = function (self, item)
	self._key_item = item
end

KeyMappingMenuPage._update_input = function (self, input)
	if not input then
		return
	end

	if input:has("cancel") and input:get("cancel") then
		self:_cancel()

		self._mouse = false
	end
end

KeyMappingMenuPage.update = function (self, dt, t, input)
	KeyMappingMenuPage.super.update(self, dt, t, input)

	if self.config.controller_type ~= Managers.input:active_mapping(1) then
		print("Controller type switch")
		self:_cancel()

		self._mouse = false

		return
	end

	if self._just_entered then
		self._just_entered = false

		return
	end

	local button = Keyboard.any_pressed()

	if button == 27 then
		return
	end

	if button ~= nil then
		local keys = self._key_item:keys()
		local new_key = Keyboard.button_name(button)

		for _, key in ipairs(keys) do
			self.config.parent_page:set_key_mapping(key, new_key, "keyboard")
		end

		self._menu_logic:cancel_to_parent()

		return
	end

	local button = Mouse.any_pressed()

	if button ~= nil then
		local keys = self._key_item:keys()
		local new_key = Mouse.button_name(button)

		for _, key in ipairs(keys) do
			self.config.parent_page:set_key_mapping(key, new_key, "mouse")
		end

		self._menu_logic:cancel_to_parent()
	end

	local pad_button = Pad1.any_pressed()

	if pad_button then
		local keys = self._key_item:keys()
		local new_key = Pad1.button_name(pad_button)

		for _, key in ipairs(keys) do
			self.config.parent_page:set_key_mapping(key, new_key, "pad")
		end

		self._menu_logic:cancel_to_parent()

		return
	end
end

KeyMappingMenuPage._set_key_mapping = function (self, key, new_key, controller)
	self.config.parent_page:set_key_mapping(key, new_key, controller)
end

KeyMappingMenuPage.render = function (self, dt, t)
	KeyMappingMenuPage.super.render(self, dt, t)
end

KeyMappingMenuPage.create_from_config = function (compiler_data, page_config, parent_page, item_groups)
	local config = {
		controller_type = "keyboard_mouse",
		parent_page = parent_page,
		render_parent_page = page_config.render_parent_page,
		z = page_config.z,
		layout_settings = page_config.layout_settings,
		sounds = page_config.sounds,
		environment = page_config.environment or parent_page and parent_page:environment()
	}

	return KeyMappingMenuPage:new(config, item_groups, compiler_data.world)
end
