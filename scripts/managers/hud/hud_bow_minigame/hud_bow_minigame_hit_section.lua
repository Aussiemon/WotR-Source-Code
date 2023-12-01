-- chunkname: @scripts/managers/hud/hud_bow_minigame/hud_bow_minigame_hit_section.lua

require("scripts/managers/hud/shared_hud_elements/hud_texture_element")

HUDBowMinigameHitSection = class(HUDBowMinigameHitSection, HUDTextureElement)

HUDBowMinigameHitSection.init = function (self, config)
	HUDBowMinigameHitSection.super.init(self, config)
end

HUDBowMinigameHitSection.update_position = function (self, dt, t, layout_settings, x, y, z)
	local config = self.config
	local blackboard = config.blackboard

	if blackboard.hitting then
		layout_settings.texture = "hud_bow_minigame_hit_section_hit"
	else
		layout_settings.texture = "hud_bow_minigame_hit_section"
	end

	HUDBowMinigameHitSection.super.update_position(self, dt, t, layout_settings, x, y, z)
end

HUDBowMinigameHitSection.create_from_config = function (config)
	return HUDBowMinigameHitSection:new(config)
end
