-- chunkname: @scripts/managers/hud/hud_call_horse/hud_call_horse_timer_background.lua

HUDCallHorseTimerBackground = class(HUDCallHorseTimerBackground, HUDTextureElement)

HUDCallHorseTimerBackground.init = function (self, config)
	HUDCallHorseTimer.super.init(self, config)
end

HUDCallHorseTimerBackground.render = function (self, dt, t, gui, layout_settings, x, y, z)
	local blackboard = self.config.blackboard
	local player_unit = blackboard.player_unit
	local locomotion = ScriptUnit.extension(player_unit, "locomotion_system")

	if locomotion.calling_horse then
		HUDCallHorseTimerBackground.super.render(self, dt, t, gui, layout_settings, x, y, z)
	end
end

HUDCallHorseTimerBackground.create_from_config = function (config)
	return HUDCallHorseTimerBackground:new(config)
end
