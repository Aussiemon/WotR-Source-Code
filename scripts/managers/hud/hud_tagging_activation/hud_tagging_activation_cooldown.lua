-- chunkname: @scripts/managers/hud/hud_tagging_activation/hud_tagging_activation_cooldown.lua

require("scripts/managers/hud/shared_hud_elements/hud_circle_cooldown")

HUDTaggingActivationCooldown = class(HUDTaggingActivationCooldown, HUDCircleCooldown)

HUDTaggingActivationCooldown.init = function (self, config)
	HUDTaggingActivationCooldown.super.init(self, config)
end

HUDTaggingActivationCooldown.render = function (self, dt, t, gui, layout_settings, x, y, z)
	local blackboard = self.config.blackboard

	if blackboard.cooldown_time - t > 0 then
		HUDTaggingActivationCooldown.super.render(self, dt, t, gui, layout_settings, x, y, z)
	end
end

HUDTaggingActivationCooldown.create_from_config = function (config)
	return HUDTaggingActivationCooldown:new(config)
end
