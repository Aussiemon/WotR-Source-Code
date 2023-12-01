-- chunkname: @scripts/managers/hud/shared_hud_elements/hud_circle_timer.lua

require("scripts/managers/hud/shared_hud_elements/hud_text_element")

HUDCircleTimer = class(HUDCircleTimer, HUDTextureElement)

HUDCircleTimer.init = function (self, config)
	HUDCircleTimer.super.init(self, config)
end

HUDCircleTimer.render = function (self, dt, t, gui, layout_settings, x, y, z)
	local config = self.config
	local blackboard = config.blackboard

	if blackboard.shader_value then
		config.gradient_shader_value = blackboard.shader_value
	else
		local remaining_time = blackboard.timer - t
		local max_time = blackboard.max_time

		config.gradient_shader_value = 1 - remaining_time / max_time
	end

	HUDCircleTimer.super.render(self, dt, t, gui, layout_settings, x, y, z)
end

HUDCircleTimer.create_from_config = function (config)
	return HUDCircleTimer:new(config)
end
