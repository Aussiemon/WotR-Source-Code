-- chunkname: @scripts/managers/hud/hud_tagging_activation/hud_tagging_activation_timer_background.lua

HUDTaggingActivationTimerBackground = class(HUDTaggingActivationTimerBackground, HUDTextureElement)

HUDTaggingActivationTimerBackground.init = function (self, config)
	HUDTaggingActivationTimerBackground.super.init(self, config)
end

HUDTaggingActivationTimerBackground.render = function (self, dt, t, gui, layout_settings, x, y, z)
	local blackboard = self.config.blackboard
	local player = blackboard.player
	local player_unit = player.player_unit
	local locomotion = ScriptUnit.extension(player_unit, "locomotion_system")

	if locomotion.tagging and locomotion.time_to_tag > 0 then
		HUDTaggingActivationTimerBackground.super.render(self, dt, t, gui, layout_settings, x, y, z)
	end
end

HUDTaggingActivationTimerBackground.create_from_config = function (config)
	return HUDTaggingActivationTimerBackground:new(config)
end
