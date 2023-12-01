-- chunkname: @scripts/managers/hud/hud_tagging/hud_tagging_loading_circle.lua

require("scripts/managers/hud/shared_hud_elements/hud_texture_element")

HUDTaggingLoadingCircle = class(HUDTaggingLoadingCircle, HUDTextureElement)

HUDTaggingLoadingCircle.init = function (self, config)
	HUDTaggingLoadingCircle.super.init(self, config)

	self._rot_angle = 0
end

HUDTaggingLoadingCircle.update_position = function (self, dt, t, layout_settings, x, y, z)
	local config = self.config
	local rot_angle = self._rot_angle
	local increment = 2 * math.pi * dt

	self._rot_angle = rot_angle <= math.pi * 2 and rot_angle + increment or increment
	config.transform_matrix = Rotation2D(Vector2(x, y), self._rot_angle, Vector2(x + self._width / 2, y + self._height / 2))

	HUDTaggingLoadingCircle.super.update_position(self, dt, t, layout_settings, x, y, z)
end

HUDTaggingLoadingCircle.create_from_config = function (config)
	return HUDTaggingLoadingCircle:new(config)
end
