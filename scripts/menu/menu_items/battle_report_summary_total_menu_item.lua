-- chunkname: @scripts/menu/menu_items/battle_report_summary_total_menu_item.lua

BattleReportSummaryTotalMenuItem = class(BattleReportSummaryTotalMenuItem, BattleReportSummaryMenuItem)

BattleReportSummaryTotalMenuItem.init = function (self, config, world)
	BattleReportSummaryTotalMenuItem.super.init(self, config, world)

	self._fade_in_alpha = 1
	self._animations[self._anim_idle] = true
	self._multiplier = nil
end

BattleReportSummaryTotalMenuItem.start = function (self)
	self.config.on_finished(self)
end

BattleReportSummaryTotalMenuItem.set_xp = function (self, xp)
	self._xp = xp
end

BattleReportSummaryTotalMenuItem.set_coins = function (self, coins)
	self._coins = coins
end

BattleReportSummaryTotalMenuItem.create_from_config = function (compiler_data, config, callback_object)
	local config = {
		disabled = true,
		type = "battle_report_scoreboard",
		page = config.page,
		name = config.name,
		callback_object = callback_object,
		on_finished = callback(callback_object, config.on_finished),
		layout_settings = config.layout_settings,
		parent_page = config.parent_page,
		sounds = config.parent_page.config.sounds.items.battle_report_summary,
		z = config.z,
		header = config.header,
		text_prefix = config.text_prefix or ""
	}

	return BattleReportSummaryTotalMenuItem:new(config, compiler_data.world)
end
