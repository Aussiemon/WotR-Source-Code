﻿-- chunkname: @scripts/managers/game_mode/game_modes/game_mode_cpu_prof.lua

require("scripts/managers/game_mode/game_modes/game_mode_base")

GameModeCpuProf = class(GameModeCpuProf, GameModeBase)

GameModeCpuProf.init = function (self, settings, world, ...)
	GameModeCpuProf.super.init(self, settings, world, ...)

	if Managers.lobby.server then
		Managers.state.event:register(self, "remote_player_destroyed", "event_remote_player_destroyed")
	end
end

GameModeCpuProf.hot_join_synch = function (self, sender, player)
	if table.size(Managers.player:players()) == 3 then
		local level = LevelHelper:current_level(self._world)

		Level.trigger_event(level, "cpu_prof_start")
	end
end

GameModeCpuProf.event_remote_player_destroyed = function (self, player)
	if table.size(Managers.player:players()) - 1 == 2 then
		local level = LevelHelper:current_level(self._world)

		Level.trigger_event(level, "cpu_prof_cleanup")
	end
end

GameModeCpuProf.evaluate_end_conditions = function (self)
	return false
end
