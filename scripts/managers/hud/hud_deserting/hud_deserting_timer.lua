-- chunkname: @scripts/managers/hud/hud_deserting/hud_deserting_timer.lua

require("scripts/managers/hud/shared_hud_elements/hud_text_element")

HUDDesertingTimer = class(HUDDesertingTimer, HUDTextElement)

HUDDesertingTimer.init = function (self, config)
	HUDDesertingTimer.super.init(self, config)
end

HUDDesertingTimer.render = function (self, dt, t, gui, layout_settings)
	local config = self.config
	local deserter_timer = config.deserter_timer
	local timer = math.ceil(deserter_timer - t)

	config.text = string.format("%.0f", timer)

	HUDDesertingTimer.super.render(self, dt, t, gui, layout_settings)
end

HUDDesertingTimer.create_from_config = function (config)
	return HUDDesertingTimer:new(config)
end
