-- chunkname: @scripts/managers/hud/hud_sprint/hud_sprint.lua

require("scripts/managers/hud/shared_hud_elements/hud_container_element")
require("scripts/managers/hud/hud_sprint/hud_sprint_icon")
require("scripts/managers/hud/hud_sprint/hud_sprint_cooldown")

HUDSprint = class(HUDSprint, HUDBase)

HUDSprint.init = function (self, world, player)
	HUDSprint.super.init(self, world, player)

	self._world = world
	self._player = player
	self._gui = World.create_screen_gui(world, "material", "materials/hud/hud", "material", MenuSettings.font_group_materials.arial, "material", MenuSettings.font_group_materials.hell_shark, "immediate")

	self:_setup_sprint_recharge()
	Managers.state.event:register(self, "event_sprint_hud_activated", "event_sprint_hud_activated", "event_sprint_hud_deactivated", "event_sprint_hud_deactivated")
end

HUDSprint._setup_sprint_recharge = function (self)
	self._sprint_container = HUDContainerElement.create_from_config({
		layout_settings = HUDSettings.sprint.container
	})

	local icon_config = {
		z = 1,
		layout_settings = table.clone(HUDSettings.sprint.icon)
	}

	self._sprint_container:add_element("icon", HUDSprintIcon.create_from_config(icon_config))

	local cooldown_config = {
		z = 2,
		layout_settings = table.clone(HUDSettings.sprint.cooldown)
	}

	self._sprint_container:add_element("cooldown", HUDSprintCooldown.create_from_config(cooldown_config))

	local key_circle_config = {
		z = 3,
		layout_settings = table.clone(HUDSettings.sprint.key_circle)
	}

	self._sprint_container:add_element("key_circle", HUDTextureElement.create_from_config(key_circle_config))

	local key_text_config = {
		text = "",
		z = 4,
		layout_settings = table.clone(HUDSettings.sprint.key_text)
	}

	self._sprint_container:add_element("key_text", HUDTextElement.create_from_config(key_text_config))
end

HUDSprint.event_sprint_hud_activated = function (self, player, blackboard)
	if player == self._player then
		self._active = true

		local elements = self._sprint_container:elements()

		for id, element in pairs(elements) do
			element.config.blackboard = blackboard
		end
	end

	local element = self._sprint_container:element("key_text")

	element.config.blackboard.text = self:_set_key(element, Managers.input:pad_active(1))
end

HUDSprint.event_sprint_hud_deactivated = function (self, player)
	if player == self._player then
		self._active = false

		local elements = self._sprint_container:elements()

		for id, element in pairs(elements) do
			element.config.blackboard = nil
		end
	end
end

HUDSprint._set_key = function (self, element, pad_active)
	local controller_settings = pad_active and "pad360" or "keyboard_mouse"
	local rush_key = ActivePlayerControllerSettings[controller_settings].rush.key
	local key_locale_name = pad_active and L("pad360_" .. rush_key) or ActivePlayerControllerSettings[controller_settings].rush.key

	key_locale_name = HUDHelper:trunkate_text(key_locale_name, 3, "...", true)

	return key_locale_name
end

HUDSprint.post_update = function (self, dt, t)
	if not self._active then
		return
	end

	self:_handle_input_switch({
		"key_text"
	}, self._sprint_container, callback(self, "_set_key"))

	local player_unit = self._player.player_unit
	local locomotion = Unit.alive(player_unit) and ScriptUnit.extension(player_unit, "locomotion_system")

	if not locomotion or locomotion.mounted_unit or not locomotion:has_perk("man_at_arms") then
		return
	end

	local layout_settings = HUDHelper:layout_settings(self._sprint_container.config.layout_settings)
	local gui = self._gui

	self._sprint_container:update_size(dt, t, gui, layout_settings)

	local x, y = HUDHelper:element_position(nil, self._sprint_container, layout_settings)

	self._sprint_container:update_position(dt, t, layout_settings, x, y, layout_settings.z)
	self._sprint_container:render(dt, t, gui, layout_settings)
end

HUDSprint.destroy = function (self)
	World.destroy_gui(self._world, self._gui)
end
