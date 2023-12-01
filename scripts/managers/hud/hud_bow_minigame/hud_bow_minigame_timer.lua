﻿-- chunkname: @scripts/managers/hud/hud_bow_minigame/hud_bow_minigame_timer.lua

require("scripts/managers/hud/shared_hud_elements/hud_texture_element")

HUDBowMinigameTimer = class(HUDBowMinigameTimer, HUDTextureElement)

HUDBowMinigameTimer.init = function (self, config)
	HUDBowMinigameTimer.super.init(self, config)
end

HUDBowMinigameTimer.update_position = function (self, dt, t, layout_settings, x, y, z)
	local config = self.config
	local blackboard = config.blackboard
	local rot_angle = config.blackboard.timer_rotations[config.name]

	config.gradient_shader_value = blackboard.shader_value
	config.transform_matrix = Rotation2D(Vector2(x, y), rot_angle, Vector2(x + self._width / 2, y + self._height / 2))

	HUDBowMinigameTimer.super.update_position(self, dt, t, layout_settings, x, y, z)
end

HUDBowMinigameTimer.create_from_config = function (config)
	return HUDBowMinigameTimer:new(config)
end
