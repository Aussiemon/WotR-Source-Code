-- chunkname: @scripts/managers/hud/hud_sp_tutorial/hud_sp_tutorial.lua

require("scripts/managers/hud/shared_hud_elements/hud_container_element")
require("scripts/managers/hud/hud_sp_tutorial/hud_sp_tutorial_element")

HUDSPTutorial = class(HUDSPTutorial, HUDBase)

HUDSPTutorial.init = function (self, world, player)
	HUDSPTutorial.super.init(self, world, player)

	self._world = world
	self._player = player
	self._gui = World.create_screen_gui(world, "material", "materials/hud/hud", "material", MenuSettings.font_group_materials.arial, "material", "materials/fonts/hell_shark_font", "material", MenuSettings.font_group_materials.wotr_hud_text, "immediate")

	self:_setup_sp_tutorial()

	self._active = false

	Managers.state.event:register(self, "tutorial_box_activated", "event_hud_sp_tutorial_activated", "tutorial_box_deactivated", "event_hud_sp_tutorial_deactivated")
end

HUDSPTutorial._setup_sp_tutorial = function (self)
	self._container = HUDContainerElement.create_from_config({
		layout_settings = table.clone(HUDSettings.sp_tutorial.container)
	})

	local text_config = {
		z = 10,
		layout_settings = table.clone(HUDSettings.sp_tutorial.tutorial_text)
	}
	local tutorial_text = HUDSPTutorialtElement.create_from_config(text_config)

	self._container:add_element("tutorial_text", tutorial_text)

	self._tutorial_text = tutorial_text
end

HUDSPTutorial.event_hud_sp_tutorial_activated = function (self, blackboard)
	self._active = true
	self._blackboard = blackboard
	self._tutorial_text.config.blackboard = blackboard
end

HUDSPTutorial.event_hud_sp_tutorial_deactivated = function (self)
	self._active = false
	self._blackboard = nil
	self._tutorial_text.config.blackboard = nil
end

HUDSPTutorial.post_update = function (self, dt, t)
	local container = self._container
	local layout_settings = HUDHelper:layout_settings(container.config.layout_settings)
	local gui = self._gui

	if self._active then
		container:update_size(dt, t, gui, layout_settings)

		local x, y = HUDHelper:element_position(nil, container, layout_settings)

		container:update_position(dt, t, layout_settings, x, y, layout_settings.z)
		container:render(dt, t, gui, layout_settings)
	end
end

HUDSPTutorial.destroy = function (self)
	World.destroy_gui(self._world, self._gui)
end
