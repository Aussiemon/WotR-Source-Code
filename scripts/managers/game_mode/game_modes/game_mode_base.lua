﻿-- chunkname: @scripts/managers/game_mode/game_modes/game_mode_base.lua

GameModeBase = class(GameModeBase)

GameModeBase.init = function (self, settings, world, win_score, time_limit)
	self._settings = settings
	self._world = world
	self._time_limit = time_limit
	self._win_score = win_score
	self._score_multiplier = 1
end

GameModeBase.team_locked_observer_cam = function (self, team)
	local game = Managers.state.network:game()

	if Managers.lobby.server or not Managers.lobby.lobby then
		return self:_team_locked_observer_cam_server(team)
	elseif game then
		return GameSession.game_object_field(game, team.game_object_id, "team_locked_observer_cam")
	end

	return false
end

GameModeBase.force_limited_observer_cam = function (self, team)
	local game = Managers.state.network:game()

	if Managers.lobby.server or not Managers.lobby.lobby then
		return self:_force_limited_observer_cam_server(team)
	elseif game then
		return GameSession.game_object_field(game, team.game_object_id, "force_limited_observer_cam")
	end

	return false
end

GameModeBase._team_locked_observer_cam_server = function (self, team)
	if Managers.admin then
		local observer_cam_settings = Managers.admin:settings().observer_camera

		return observer_cam_settings and observer_cam_settings.team_locked
	else
		return true
	end
end

GameModeBase._force_limited_observer_cam_server = function (self, team)
	if Managers.admin then
		local observer_cam_settings = Managers.admin:settings().observer_camera

		return observer_cam_settings and observer_cam_settings.force_limited
	else
		return true
	end
end

GameModeBase.allowed_spawns = function (self, team)
	local game = Managers.state.network:game()

	if Managers.lobby.server or not Managers.lobby.lobby then
		return self:_allowed_spawns_spawn_owner(team)
	elseif game then
		local spawns = GameSession.game_object_field(game, team.game_object_id, "allowed_spawns")

		if spawns == -1 then
			return math.huge
		else
			return spawns
		end
	end

	return 0
end

GameModeBase._allowed_spawns_spawn_owner = function (self, team)
	return math.huge
end

GameModeBase.win_scale = function (self)
	local score = 0
	local team_manager = Managers.state.team

	for _, side in pairs(team_manager:sides()) do
		local team = team_manager:team_by_side(side)

		score = math.max(score, team.score)
	end

	local win_scale = math.clamp(score / self._win_score, 0, 1)

	return win_scale
end

GameModeBase.evaluate_end_conditions = function (self)
	local team_manager = Managers.state.team
	local win_score = self._win_score

	for _, side in pairs(team_manager:sides()) do
		local team = team_manager:team_by_side(side)

		if win_score <= team.score then
			return true, team
		end
	end

	return false, nil
end

GameModeBase.custom_spawning = function (self)
	return nil
end

GameModeBase.modified_score = function (self, score)
	return score * self._score_multiplier
end

GameModeBase.object_sets = function (self)
	return self._settings.object_sets
end

GameModeBase.win_score = function (self)
	return self._win_score
end

GameModeBase.objective = function (self, player)
	return "", nil, nil
end

GameModeBase.time_announcement = function (self, local_player)
	local time_limit = self._time_limit
	local round_time = Managers.time:time("round")

	if not time_limit or not round_time then
		return ""
	end

	local announcement = ""

	if round_time > time_limit / 2 - 1 and round_time < time_limit / 2 + 5 then
		-- Nothing
	elseif round_time > time_limit - 11 then
		announcement = "only_time_left"
	end

	local param1, param2 = GameModeHelper:announcement_parameters(announcement, local_player, self._world)

	return announcement, param1, param2
end

GameModeBase.own_score_announcement = function (self)
	return ""
end

GameModeBase.enemy_score_announcement = function (self)
	return ""
end

GameModeBase.own_capture_point_announcement = function (self)
	return ""
end

GameModeBase.enemy_capture_point_announcement = function (self)
	return ""
end

GameModeBase.hud_score_text = function (self)
	return ""
end

GameModeBase.hud_progress = function (self)
	return 0, 0.5, 1, false
end

GameModeBase.hud_timer_text = function (self)
	local t, t_alert

	if self._time_limit then
		t = self._time_limit - math.max(Managers.time:time("round"), 0)
		t_alert = t >= 0 and self._settings.time_limit_alert and t < self._settings.time_limit_alert
	else
		t = math.max(Managers.time:time("round"), 0)
	end

	if t < math.huge then
		local minutes = math.floor(math.max(t, 0) / 60)
		local seconds = math.floor(math.max(t, 0) % 60)

		return string.format("%02.f:%02.f", minutes, seconds), t_alert
	else
		return "", false
	end
end

GameModeBase.set_time_limit = function (self, t)
	self._time_limit = t
end

GameModeBase.modify_time_limit = function (self, t)
	self._time_limit = self._time_limit + t
end

GameModeBase.time_limit = function (self)
	return self._time_limit
end

GameModeBase.hot_join_synch = function (self, sender, player)
	return
end
