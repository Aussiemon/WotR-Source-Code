-- chunkname: @scripts/managers/game_mode/spawn_modes/personal_spawning.lua

require("scripts/managers/game_mode/spawn_modes/spawning_base")

PersonalSpawning = class(PersonalSpawning, SpawningBase)

PersonalSpawning.init = function (self, settings, game_mode)
	PersonalSpawning.super.init(self, settings, game_mode)
end

PersonalSpawning.setup = function (self)
	return
end

PersonalSpawning.next_spawn_time = function (self, player)
	local side = player.team.side
	local settings = self._settings

	if side then
		return math.max(self._t, 0) + settings[side .. "_respawn_time"] or settings.respawn_time
	else
		return math.huge
	end
end

PersonalSpawning.update = function (self)
	self._t = Managers.time:time("round")
end
