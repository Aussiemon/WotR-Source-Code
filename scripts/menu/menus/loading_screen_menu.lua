-- chunkname: @scripts/menu/menus/loading_screen_menu.lua

require("scripts/menu/menus/menu")
require("scripts/menu/menu_compiler")
require("scripts/menu/menu_logic")
require("scripts/menu/menu_containers/loading_indicator_menu_container")
require("gui/textures/prizes_medals_unlocks_atlas")

LoadingScreenMenu = class(LoadingScreenMenu, Menu)

LoadingScreenMenu.init = function (self, state, world, controller_settings, menu_settings, menu_definition, menu_callbacks, menu_data)
	LoadingScreenMenu.super.init(self, state, world, controller_settings, menu_settings, menu_definition, menu_callbacks, menu_data)

	local layout_settings = MenuHelper:layout_settings(self._menu_settings.items.loading_indicator)

	self._loading_indicator = LoadingIndicatorMenuContainer.create_from_config(layout_settings, world)

	Managers.state.event:register(self, "event_load_started", "load_started", "event_load_finished", "load_finished", "event_save_started", "save_started", "event_save_finished", "save_finished")
end

LoadingScreenMenu.update = function (self, dt, t)
	LoadingScreenMenu.super.update(self, dt, t)

	local layout_settings = MenuHelper:layout_settings(self._menu_settings.items.loading_indicator)

	self._loading_indicator:update_size(dt, t, self._gui, layout_settings)

	local x, y = MenuHelper:container_position(self._loading_indicator, layout_settings)

	self._loading_indicator:update_position(dt, t, layout_settings, x, y, 500)
	self._loading_indicator:render(dt, t, self._gui, layout_settings)
end

LoadingScreenMenu.load_started = function (self, text_loading, text_loaded)
	self._loading_indicator:load_started(text_loading, text_loaded)
end

LoadingScreenMenu.load_finished = function (self)
	self._loading_indicator:load_finished()
end

LoadingScreenMenu.save_started = function (self, text_saving, text_saved)
	self._loading_indicator:save_started(text_saving, text_saved)
end

LoadingScreenMenu.save_finished = function (self)
	self._loading_indicator:save_finished()
end

LoadingScreenMenu.destroy = function (self)
	LoadingScreenMenu.super.destroy(self)
	World.destroy_gui(self._world, self._gui)
end
