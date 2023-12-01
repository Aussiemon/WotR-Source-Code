-- chunkname: @scripts/managers/game_mode/game_modes/game_mode_sp.lua

require("scripts/managers/game_mode/game_modes/game_mode_base")

GameModeSP = class(GameModeSP, GameModeBase)

GameModeSP.init = function (self, settings, world, ...)
	GameModeSP.super.init(self, settings, world, ...)
end

GameModeSP.objective = function (self)
	return nil
end

GameModeSP.hud_timer_text = function (self)
	return ""
end

GameModeSP.hud_progress = function (self, local_player)
	local defenders_score = Managers.state.team:team_by_side("defenders").score
	local center

	if local_player.team.side == "defenders" then
		center = defenders_score / self._win_score
	else
		center = 1 - defenders_score / self._win_score
	end

	return 0, center, 1, true
end
