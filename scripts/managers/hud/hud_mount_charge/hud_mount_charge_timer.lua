-- chunkname: @scripts/managers/hud/hud_mount_charge/hud_mount_charge_timer.lua

require("scripts/managers/hud/shared_hud_elements/hud_text_element")

HUDMountChargeTimer = class(HUDMountChargeTimer, HUDCircleTimer)

HUDMountChargeTimer.init = function (self, config)
	HUDMountChargeTimer.super.init(self, config)
end

HUDMountChargeTimer.render = function (self, dt, t, gui, layout_settings, x, y, z)
	local blackboard = self.config.blackboard
	local mount_locomotion = blackboard.mount_locomotion

	if mount_locomotion.charging then
		HUDMountChargeTimer.super.render(self, dt, t, gui, layout_settings, x, y, z)
	end
end

HUDMountChargeTimer.create_from_config = function (config)
	return HUDMountChargeTimer:new(config)
end
