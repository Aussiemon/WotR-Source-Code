-- chunkname: @scripts/menu/menu_pages/splash_screen_menu_page.lua

require("scripts/menu/menu_containers/texture_menu_container")
require("scripts/menu/menu_containers/frame_texture_menu_container")

SplashScreenMenuPage = class(SplashScreenMenuPage, MenuPage)

SplashScreenMenuPage.init = function (self, config, item_groups, world)
	SplashScreenMenuPage.super.init(self, config, item_groups, world)

	self._world = world

	local layout_settings = MenuHelper:layout_settings(self.config.layout_settings)

	self._item_list = ItemListMenuContainer.create_from_config(item_groups.item_list)
end

SplashScreenMenuPage.on_enter = function (self)
	SplashScreenMenuPage.super.on_enter(self)
	self:_try_callback(self.config.callback_object, self.config.on_enter_page)
end

SplashScreenMenuPage.on_exit = function (self, on_cancel)
	SplashScreenMenuPage.super.on_exit(self, on_cancel)
	self:_try_callback(self.config.callback_object, self.config.on_exit_page)
end

SplashScreenMenuPage._update_input = function (self, input)
	if not input then
		return
	end

	if input:has("select") and input:get("select") or input:has("space") and input:get("space") then
		self:_try_callback(self.config.callback_object, self.config.on_continue_input, self.config.on_continue_input_args)
	end
end

SplashScreenMenuPage._update_mouse_hover = function (self, input)
	if not input then
		return
	end

	if input:get("select_left_click") then
		self:_try_callback(self.config.callback_object, self.config.on_continue_input, self.config.on_continue_input_args)
	end
end

SplashScreenMenuPage.goto_first_items_page = function (self)
	local item = self._items[1]

	if item and item.config.page then
		self._menu_logic:change_page(item.config.page)
	end
end

SplashScreenMenuPage.update = function (self, dt, t)
	SplashScreenMenuPage.super.update(self, dt, t)
	self:_update_container_size(dt, t)
	self:_update_container_position(dt, t)
end

SplashScreenMenuPage._update_container_size = function (self, dt, t)
	local layout_settings = MenuHelper:layout_settings(self.config.layout_settings)

	self._item_list:update_size(dt, t, self._gui, layout_settings.item_list)
end

SplashScreenMenuPage._update_container_position = function (self, dt, t)
	local layout_settings = MenuHelper:layout_settings(self.config.layout_settings)
	local x, y = MenuHelper:container_position(self._item_list, layout_settings.item_list)

	self._item_list:update_position(dt, t, layout_settings.item_list, x, y, self.config.z + 15)
end

SplashScreenMenuPage.render = function (self, dt, t)
	SplashScreenMenuPage.super.render(self, dt, t)

	local layout_settings = MenuHelper:layout_settings(self.config.layout_settings)

	self._item_list:render(dt, t, self._gui, layout_settings.item_list)
end

SplashScreenMenuPage.application_render = function (self)
	for index, item in ipairs(self._items) do
		if item.application_render then
			item:application_render()
		end
	end
end

SplashScreenMenuPage.create_from_config = function (compiler_data, page_config, parent_page, item_groups, callback_object)
	local config = {
		type = page_config.type,
		parent_page = parent_page,
		callback_object = callback_object,
		on_continue_input = page_config.on_continue_input,
		on_continue_input_args = page_config.on_continue_input_args or {},
		on_enter_page = page_config.on_enter_page,
		on_exit_page = page_config.on_exit_page,
		no_cancel_to_parent_page = page_config.no_cancel_to_parent_page,
		z = page_config.z,
		layout_settings = page_config.layout_settings,
		sounds = page_config.sounds,
		environment = page_config.environment or parent_page and parent_page:environment()
	}

	return SplashScreenMenuPage:new(config, item_groups, compiler_data.world)
end
