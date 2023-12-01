﻿-- chunkname: @scripts/managers/hud/hud_chat/hud_chat.lua

require("scripts/managers/hud/shared_hud_elements/hud_container_element")
require("scripts/managers/hud/shared_hud_elements/hud_text_input_element")

HUDChat = class(HUDChat, HUDBase)

HUDChat.init = function (self, world, player)
	HUDChat.super.init(self, world, player)

	self._world = world
	self._player = player
	self._gui = World.create_screen_gui(world, "material", "materials/hud/mockup_hud", "material", MenuSettings.font_group_materials.arial, "material", "materials/fonts/hell_shark_font", "immediate")
	self._active = false

	self:_setup_chat()
	Managers.state.event:register(self, "event_chat_initiated", "event_chat_initiated")
	Managers.state.event:register(self, "event_chat_input_activated", "event_chat_input_activated")
	Managers.state.event:register(self, "event_chat_input_deactivated", "event_chat_input_deactivated")
end

HUDChat._setup_chat = function (self)
	self._chat_container = HUDContainerElement.create_from_config({
		layout_settings = HUDSettings.chat.container
	})
end

HUDChat.event_chat_initiated = function (self, blackboard)
	local input_text_config = {
		text = "",
		blackboard = blackboard,
		layout_settings = HUDSettings.chat.input_text
	}

	self._chat_container:add_element("text_input", HUDTextInputElement.create_from_config(input_text_config))
end

HUDChat.event_chat_input_activated = function (self)
	self._active = true
end

HUDChat.event_chat_input_deactivated = function (self)
	self._active = false
end

HUDChat.post_update = function (self, dt, t)
	if not self._active then
		return
	end

	local layout_settings = HUDHelper:layout_settings(self._chat_container.config.layout_settings)
	local gui = self._gui

	self._chat_container:update_size(dt, t, gui, layout_settings)

	local x, y = HUDHelper:element_position(nil, self._chat_container, layout_settings)

	self._chat_container:update_position(dt, t, layout_settings, x, y, layout_settings.z)
	self._chat_container:render(dt, t, gui, layout_settings)
end

HUDChat.destroy = function (self)
	World.destroy_gui(self._world, self._gui)
end
