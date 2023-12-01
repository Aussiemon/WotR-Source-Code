-- chunkname: @scripts/unit_extensions/default_player_unit/states/player_bandaging_self.lua

require("scripts/unit_extensions/default_player_unit/states/player_bandaging_teammate")

PlayerBandagingSelf = class(PlayerBandagingSelf, PlayerBandagingTeammate)

local BUTTON_THRESHOLD = 0.5

PlayerBandagingSelf.init = function (self, unit, internal, world)
	PlayerBandagingSelf.super.super.init(self, unit, internal, world, "bandage_self")

	self._controller_mapping = "bandage"
end

PlayerBandagingSelf._interact_duration = function (self)
	local internal = self._internal
	local duration_multiplier = (internal:has_perk("surgeon") and Perks.surgeon.self_duration_multiplier or 1) * (internal:has_perk("regenerative") and Perks.regenerative.self_duration_multiplier or 1)

	return PlayerBandagingSelf.super.super._interact_duration(self) * duration_multiplier
end
