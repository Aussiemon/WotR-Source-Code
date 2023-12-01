-- chunkname: @scripts/managers/hud/hud_crossbow_minigame/hud_crossbow_minigame_timer.lua

require("scripts/managers/hud/shared_hud_elements/hud_texture_element")

HUDCrossbowMinigameTimer = class(HUDCrossbowMinigameTimer, HUDTextureElement)

HUDCrossbowMinigameTimer.init = function (self, config)
	HUDCrossbowMinigameTimer.super.init(self, config)
end

HUDCrossbowMinigameTimer.update_position = function (self, dt, t, layout_settings, x, y, z)
	local config = self.config
	local blackboard = config.blackboard
	local trans_pos_x = blackboard.circle_pos_x - self._width / 2
	local trans_pos_y = blackboard.circle_pos_y - self._height / 2

	config.gradient_shader_value = blackboard.shader_value

	HUDCrossbowMinigameTimer.super.update_position(self, dt, t, layout_settings, trans_pos_x, trans_pos_y, z)
end

HUDCrossbowMinigameTimer.create_from_config = function (config)
	return HUDCrossbowMinigameTimer:new(config)
end
