-- chunkname: @scripts/managers/game_mode/spawn_modes/spawning_base.lua

SpawningBase = class(SpawningBase)

SpawningBase.init = function (self, settings, game_mode)
	self._settings = settings

	local mode = settings.squad_spawn_mode

	fassert(not mode or mode == "on" or mode == "off" or mode == "no_combat", "[SpawningBase] Server setting spawning.squad_spawn_mode is: %q. Valid values are: \"on\", \"off\", \"no_combat\".")
end

SpawningBase.round_started = function (self)
	return
end

SpawningBase.squad_spawn_mode = function (self)
	return self._settings.squad_spawn_mode or "on"
end

SpawningBase.squad_spawn_stun = function (self)
	return self._settings.squad_spawn_stun or false
end

SpawningBase.setup = function (self)
	return
end

SpawningBase.next_spawn_time = function (self, player)
	ferror("[SpawningBase] next_spawn_time not implemented!")
end

SpawningBase.update = function (self, dt, t)
	return
end
