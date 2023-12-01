-- chunkname: @scripts/managers/hud/hud_mount_charge/hud_mount_charge_cooldown.lua

require("scripts/managers/hud/shared_hud_elements/hud_circle_cooldown")

HUDMountChargeCooldown = class(HUDMountChargeCooldown, HUDCircleCooldown)

HUDMountChargeCooldown.init = function (self, config)
	HUDMountChargeCooldown.super.init(self, config)
end

HUDMountChargeCooldown.render = function (self, dt, t, gui, layout_settings, x, y, z)
	local blackboard = self.config.blackboard
	local mount_locomotion = blackboard.mount_locomotion

	if blackboard.cooldown_shader_value > 0 and not mount_locomotion.charging then
		HUDMountChargeCooldown.super.render(self, dt, t, gui, layout_settings, x, y, z)
	end
end

HUDMountChargeCooldown.create_from_config = function (config)
	return HUDMountChargeCooldown:new(config)
end
