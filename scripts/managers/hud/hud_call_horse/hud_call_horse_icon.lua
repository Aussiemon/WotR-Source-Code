-- chunkname: @scripts/managers/hud/hud_call_horse/hud_call_horse_icon.lua

require("scripts/managers/hud/shared_hud_elements/hud_texture_element")

HUDCallHorseIcon = class(HUDCallHorseIcon, HUDTextureElement)

HUDCallHorseIcon.init = function (self, config)
	HUDCallHorseIcon.super.init(self, config)
end

HUDCallHorseIcon.render = function (self, dt, t, gui, layout_settings)
	local config = self.config
	local blackboard = config.blackboard
	local player_unit = blackboard.player_unit
	local locomotion = ScriptUnit.extension(player_unit, "locomotion_system")

	if locomotion.current_state:can_call_horse(player_unit, t) then
		layout_settings.color = {
			255,
			255,
			255,
			255
		}
	else
		layout_settings.color = {
			255,
			150,
			150,
			150
		}
	end

	layout_settings.texture_atlas_settings = HUDAtlas.call_horse

	HUDCallHorseIcon.super.render(self, dt, t, gui, layout_settings)
end

HUDCallHorseIcon.create_from_config = function (config)
	return HUDCallHorseIcon:new(config)
end
