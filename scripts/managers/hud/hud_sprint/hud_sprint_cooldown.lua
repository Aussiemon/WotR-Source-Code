-- chunkname: @scripts/managers/hud/hud_sprint/hud_sprint_cooldown.lua

require("scripts/managers/hud/shared_hud_elements/hud_circle_cooldown")

HUDSprintCooldown = class(HUDSprintCooldown, HUDCircleCooldown)

HUDSprintCooldown.init = function (self, config)
	HUDSprintCooldown.super.init(self, config)
end

HUDSprintCooldown.render = function (self, dt, t, gui, layout_settings, x, y, z)
	local blackboard = self.config.blackboard

	if blackboard.cooldown_shader_value > 0 then
		HUDSprintCooldown.super.render(self, dt, t, gui, layout_settings, x, y, z)
	end
end

HUDSprintCooldown.create_from_config = function (config)
	return HUDSprintCooldown:new(config)
end
