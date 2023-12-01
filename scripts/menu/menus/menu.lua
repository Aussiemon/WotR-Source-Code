﻿-- chunkname: @scripts/menu/menus/menu.lua

require("scripts/menu/menu_compiler")
require("scripts/menu/menu_logic")

Menu = class(Menu)

Menu.init = function (self, state, world, controller_settings, menu_settings, menu_definition, menu_callbacks, menu_data)
	self._world = world
	self._menu_settings = menu_settings

	self:_create_gui()
	World.set_data(self._world, "menu_gui", self._gui)

	local menu_callbacks = menu_callbacks:new(state)
	local compiler_data = {
		callback_object = menu_callbacks,
		world = world,
		menu_data = menu_data
	}
	local compiler = MenuCompiler:new(compiler_data)
	local compiled_menu_definition, menu_shortcuts = compiler:compile(menu_definition)
	local on_enter_page_callback = callback(self, "cb_on_enter_page")

	self._menu_logic = MenuLogic:new(compiled_menu_definition, menu_shortcuts, world, on_enter_page_callback)
	self._input_source = Managers.input:map_slot(1, controller_settings, nil)
	self._active = false

	self:_try_play_music_events("on_menu_init")
end

Menu._create_gui = function (self)
	self._gui = World.create_screen_gui(self._world, "material", "materials/menu/loading_atlas", "material", "materials/menu/splash_screen", "material", "materials/fonts/splash_screen_font", "material", "materials/fonts/hell_shark_font", "material", "materials/menu/menu", "material", MenuSettings.font_group_materials.font_gradient_100, "material", MenuSettings.font_group_materials.wotr_hud_text, "material", MenuSettings.font_group_materials.arial, "material", "materials/hud/minimap", "material", "materials/hud/buttons", "material", "materials/hud/hud", "immediate")
end

Menu.update = function (self, dt, t)
	if self._active then
		self._menu_logic:update(dt, t, self._input_source)
	end
end

Menu.goto = function (self, id)
	self._menu_logic:goto(id)
end

Menu.current_page = function (self)
	return self._menu_logic:current_page()
end

Menu.current_page_type = function (self)
	return self._menu_logic:current_page_type()
end

Menu.current_parent_page_type = function (self)
	return self._menu_logic:current_parent_page_type()
end

Menu.cancel_to = function (self, page_id)
	self._menu_logic:cancel_to(page_id)
end

Menu.active = function (self)
	return self._active
end

Menu.set_active = function (self, active)
	self._active = active

	if active then
		self._menu_logic:menu_activated()
		self:_try_play_music_events("on_menu_activate")
	else
		self._menu_logic:menu_deactivated()
		self:_try_play_music_events("on_menu_deactivate")
	end
end

Menu.current_page_is_root = function (self)
	return self._menu_logic:current_page_is_root()
end

Menu._try_play_music_events = function (self, menu_event)
	local music_events = self._menu_settings.music_events

	if music_events and music_events[menu_event] then
		for i, music_event in ipairs(music_events[menu_event]) do
			Managers.music:trigger_event(music_event)
		end
	end
end

Menu.cb_on_enter_page = function (self, page)
	return
end

Menu.destroy = function (self)
	Managers.input:unmap_input_source(self._input_source)
	self._menu_logic:destroy()

	self._menu_logic = nil

	self:_try_play_music_events("on_menu_destroy")
end
