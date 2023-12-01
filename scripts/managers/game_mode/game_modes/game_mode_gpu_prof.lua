-- chunkname: @scripts/managers/game_mode/game_modes/game_mode_gpu_prof.lua

require("scripts/managers/game_mode/game_modes/game_mode_base")

GameModeGpuProf = class(GameModeGpuProf, GameModeBase)

GameModeGpuProf.init = function (self, settings, world, ...)
	GameModeGpuProf.super.init(self, settings, world, ...)

	if not Managers.lobby.server and Managers.lobby.lobby then
		Managers.state.event:register(self, "game_started", "event_game_started")
	end
end

GameModeGpuProf.event_game_started = function (self)
	local level = LevelHelper:current_level(self._world)

	Level.trigger_event(level, "client_gpu_prof")
end

GameModeGpuProf.evaluate_end_conditions = function (self)
	return false
end
