-- chunkname: @scripts/managers/hud/hud_tagging/hud_tagging.lua

require("scripts/managers/hud/shared_hud_elements/hud_container_element")
require("scripts/managers/hud/hud_tagging/hud_tagging_loading_circle")

HUDTagging = class(HUDTagging, HUDBase)

HUDTagging.init = function (self, world, player)
	HUDTagging.super.init(self, world, player)

	self._world = world
	self._player = player
	self._gui = World.create_screen_gui(world, "material", "materials/hud/mockup_hud", "material", MenuSettings.font_group_materials.arial, "immediate")

	self:_setup_tagging()
	Managers.state.event:register(self, "started_tagging", "event_tagging_activated", "stopped_tagging", "event_tagging_deactivated")
end

HUDTagging._setup_tagging = function (self)
	self._tagging_container = HUDContainerElement.create_from_config({
		layout_settings = HUDSettings.tagging.container
	})

	local loading_circle_config = {
		z = 10,
		layout_settings = HUDSettings.tagging.loading_circle
	}

	self._tagging_container:add_element("timer", HUDTaggingLoadingCircle.create_from_config(loading_circle_config))
end

HUDTagging.event_tagging_activated = function (self, player)
	if player == self._player then
		self._active = true
	end
end

HUDTagging.event_tagging_deactivated = function (self, player)
	if player == self._player then
		self._active = false
	end
end

HUDTagging.post_update = function (self, dt, t)
	if not self._active then
		return
	end

	local layout_settings = HUDHelper:layout_settings(self._tagging_container.config.layout_settings)
	local gui = self._gui

	self._tagging_container:update_size(dt, t, gui, layout_settings)

	local x, y = HUDHelper:element_position(nil, self._tagging_container, layout_settings)

	self._tagging_container:update_position(dt, t, layout_settings, x, y, layout_settings.z)
	self._tagging_container:render(dt, t, gui, layout_settings)
end

HUDTagging.destroy = function (self)
	World.destroy_gui(self._world, self._gui)
end
