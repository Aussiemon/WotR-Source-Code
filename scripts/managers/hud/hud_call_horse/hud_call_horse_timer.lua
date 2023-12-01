-- chunkname: @scripts/managers/hud/hud_call_horse/hud_call_horse_timer.lua

require("scripts/managers/hud/shared_hud_elements/hud_text_element")

HUDCallHorseTimer = class(HUDCallHorseTimer, HUDCircleTimer)

HUDCallHorseTimer.init = function (self, config)
	HUDCallHorseTimer.super.init(self, config)
end

HUDCallHorseTimer.render = function (self, dt, t, gui, layout_settings, x, y, z)
	local blackboard = self.config.blackboard
	local player_unit = blackboard.player_unit
	local locomotion = ScriptUnit.extension(player_unit, "locomotion_system")

	if locomotion.calling_horse then
		HUDCallHorseTimer.super.render(self, dt, t, gui, layout_settings, x, y, z)
	end
end

HUDCallHorseTimer.create_from_config = function (config)
	return HUDCallHorseTimer:new(config)
end
