﻿-- chunkname: @scripts/managers/persistence/telemetry_collector.lua

TelemetryCollector = class(TelemetryCollector)

TelemetryCollector.init = function (self, template_name)
	cprint("TelemetryCollector:init")
	Telemetry.init(template_name)
end

TelemetryCollector.setup = function (self)
	Managers.state.event:register(self, "player_enemy_kd", "event_player_enemy_kd", "player_enemy_kill", "event_player_enemy_kill", "player_spawned_in_area", "event_player_spawned_in_area", "player_spawned_at_unit", "event_player_spawned_at_unit")

	local level_key = Managers.state.game_mode:level_key()

	self._map_id = LevelSettings[level_key].map_id
	self._game_mode = Managers.state.game_mode:game_mode_key()

	Telemetry.new_data_set()
end

TelemetryCollector.event_player_enemy_kd = function (self, victim, killer, gear_name, damage_type)
	if Unit.alive(victim.player_unit) and Unit.alive(killer.player_unit) then
		Telemetry.write_record("kills", Application.utc_time(), self._map_id, self._game_mode, killer.team.name, Unit.world_position(killer.player_unit, 0), Gear[gear_name].hash, killer.backend_profile_id, victim.team.name, Unit.world_position(victim.player_unit, 0), victim.backend_profile_id)
	end
end

TelemetryCollector.event_player_enemy_kill = function (self, victim, killer, gear_name, is_instakill, damagers)
	if is_instakill and Unit.alive(victim.player_unit) and Unit.alive(killer.player_unit) then
		Telemetry.write_record("kills", Application.utc_time(), self._map_id, self._game_mode, killer.team.name, Unit.world_position(killer.player_unit, 0), Gear[gear_name].hash, killer.backend_profile_id, victim.team.name, Unit.world_position(victim.player_unit, 0), victim.backend_profile_id)
	end
end

TelemetryCollector.event_player_spawned_in_area = function (self, player, player_pos)
	Telemetry.write_record("spawns", Application.utc_time(), self._map_id, self._game_mode, "area", player.team.name, player_pos, player.backend_profile_id)
end

TelemetryCollector.event_player_spawned_at_unit = function (self, player, squad_player, player_pos)
	Telemetry.write_record("spawns", Application.utc_time(), self._map_id, self._game_mode, "unit", player.team.name, player_pos, player.backend_profile_id)
end

TelemetryCollector.save_round = function (self, player)
	Telemetry.write_record("rounds", Application.utc_time(), self._map_id, self._game_mode, Managers.time:time("round") - player.round_time_joined, Managers.state.stats_collection:get(player:network_id(), "experience_round"), player.backend_profile_id)
end

TelemetryCollector.finalize = function (self)
	Telemetry.close_data_set()
end
