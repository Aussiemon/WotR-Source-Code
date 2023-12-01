-- chunkname: @scripts/managers/game_mode/spawn_modes/single_player_spawning.lua

require("scripts/managers/game_mode/spawn_modes/spawning_base")

SinglePlayerSpawning = class(SinglePlayerSpawning, SpawningBase)

SinglePlayerSpawning.next_spawn_time = function (self, player)
	return 0
end
