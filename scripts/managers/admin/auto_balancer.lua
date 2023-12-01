-- chunkname: @scripts/managers/admin/auto_balancer.lua

AutoBalancer = class(AutoBalancer)

AutoBalancer.init = function (self, settings)
	if settings then
		self._settings = settings

		self:_parse_settings()

		self._teams = {
			unassigned = 0,
			red = 0,
			white = 0
		}
		self._state = "balanced"
		self._enabled = true
	else
		self._enabled = false
	end
end

AutoBalancer._parse_settings = function (self)
	self._settings.player_threshold = math.clamp(self._settings.player_threshold or 2, 2, math.huge)
end

AutoBalancer.setup = function (self)
	if self._enabled then
		self._active = true
		self._stats = Managers.state.stats_collection
		self._players = Managers.player:players()

		Managers.state.event:register(self, "player_joined_team", "event_player_joined_team")
		Managers.state.event:register(self, "player_left_team", "event_player_left_team")
		Managers.state.event:register(self, "event_level_ended", "event_level_ended")
	end
end

AutoBalancer.event_player_joined_team = function (self, player)
	if self._active and player.team.name ~= "unassigned" then
		self._teams[player.team.name] = self._teams[player.team.name] + 1

		self:_evaluate_teams()
	end
end

AutoBalancer.event_player_left_team = function (self, player)
	if self._active and player.team.name ~= "unassigned" then
		self._teams[player.team.name] = self._teams[player.team.name] - 1

		self:_evaluate_teams()
	end
end

AutoBalancer.event_level_ended = function (self)
	self._teams.white, self._teams.red, self._teams.unassigned = 0, 0, 0
	self._active = false
end

AutoBalancer._evaluate_teams = function (self)
	local player_diff = self._teams.white - self._teams.red

	if math.abs(player_diff) >= self._settings.player_threshold then
		self._state = "balancing"

		local favoured_team_name = player_diff > 0 and "white" or "red"
		local favoured_team = Managers.state.team:team_by_name(favoured_team_name)

		self:_balance_team(favoured_team)
	else
		self._state = "balanced"
	end
end

AutoBalancer._balance_team = function (self, favoured_team)
	print("Rebalancing", favoured_team.name)

	self._favoured_team = favoured_team
	self._picked_player = self:_pick_player(favoured_team)
end

AutoBalancer._pick_player = function (self, favoured_team)
	local player_scores = {}

	for _, player in pairs(favoured_team.members) do
		local player_score = self._stats:get(player:network_id(), "experience_round")

		player_scores[#player_scores + 1] = {
			player = player,
			score = player_score
		}
	end

	table.sort(player_scores, function (e1, e2)
		return e1.score > e2.score
	end)

	return player_scores[2].player
end

AutoBalancer.update = function (self, dt, t)
	if self._enabled and self._active and self._state == "balancing" then
		local spawn_state = self._picked_player.spawn_data.state

		if spawn_state == "dead" then
			self._state = "balanced"

			local opposite_team = Managers.state.team:opposite_team(self._favoured_team)

			Managers.state.team:move_player_to_team_by_name(self._picked_player, opposite_team.name)
		end
	end
end
