﻿-- chunkname: @scripts/managers/hud/hud_player_effects/hud_player_effect_information_icon.lua

require("scripts/managers/hud/shared_hud_elements/hud_texture_element")

HUDPlayerEffectInformationIcon = class(HUDPlayerEffectInformationIcon, HUDTextureElement)

HUDPlayerEffectInformationIcon.init = function (self, config)
	HUDPlayerEffectInformationIcon.super.init(self, config)
end

HUDPlayerEffectInformationIcon.render = function (self, dt, t, gui, layout_settings)
	local config = self.config
	local effect_type = config.effect_type
	local blackboard = config.blackboard[effect_type]
	local buff_settings = Buffs[effect_type]
	local debuff_settings = Debuffs[effect_type]
	local level = blackboard.level

	if buff_settings and level > 0 or not buff_settings and level > 1 then
		HUDPlayerEffectInformationIcon.super.render(self, dt, t, gui, layout_settings)
	end
end

HUDPlayerEffectInformationIcon.create_from_config = function (config)
	return HUDPlayerEffectInformationIcon:new(config)
end
