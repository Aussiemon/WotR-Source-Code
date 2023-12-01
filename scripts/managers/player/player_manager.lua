-- chunkname: @scripts/managers/player/player_manager.lua

PlayerManager.init = function (self)
	self._players = {}
	self._remote_players = {}
	self._unit_owners = {}
end

PlayerManager.assign_unit_ownership = function (self, unit, player_index, is_player_unit)
	fassert(self._unit_owners[unit] == nil, "[PlayerManager:add_unit_ownership] Unit %s already is owned by player %q and can't be assigned to player %q", unit, self._unit_owners[unit] and self._unit_owners[unit].index, player_index)
	fassert(self._players[player_index], "[PlayerManager:add_unit_ownership] Unit %s cannot be assigned to be owned by player %q as this player does not exist.", unit, player_index)

	self._unit_owners[unit] = self._players[player_index]
	self._players[player_index].owned_units[unit] = unit

	if is_player_unit then
		self._players[player_index].player_unit = unit
	end

	Unit.set_data(unit, "owner_player_index", player_index)
end

PlayerManager.relinquish_unit_ownership = function (self, unit)
	fassert(self._unit_owners[unit], "[PlayerManager:relinquish_unit_ownership] Unit %s ownership cannot be relinquished, not owned.", unit)

	local unit_owner = self._unit_owners[unit]

	if unit == unit_owner.player_unit then
		unit_owner.player_unit = nil
	end

	self._unit_owners[unit] = nil
	unit_owner.owned_units[unit] = nil

	Unit.set_data(unit, "owner_player_index", nil)
end

PlayerManager.add_player = function (self, coat_of_arms, player_index, input_slot, input_source, viewport_name, viewport_world_name)
	assert(not self._players[player_index], "[PlayerManager:add_player] Trying to add player " .. tostring(player_index) .. " to already existing index.")

	local player = PostmanPlayer:new(coat_of_arms, player_index, input_slot, input_source, viewport_name, viewport_world_name)

	self._players[player_index] = player
end

PlayerManager.add_remote_player = function (self, local_id, temp_random_user_id, peer, backend_profile_id, is_demo)
	local player = RemotePlayer:new(local_id, temp_random_user_id, peer, backend_profile_id, is_demo)
	local player_index = player:player_id()

	self._players[player_index] = player

	return player
end

PlayerManager.add_ai_player = function (self, player_index)
	fassert(self._players[player_index] == nil, "Player %q already exists", player_index)

	local player = AIPlayer:new(player_index)

	self._players[player_index] = player

	Managers.state.event:trigger("ai_player_created", player)
end

PlayerManager.remove_player = function (self, player_index)
	local player = self._players[player_index]
	local owned_units = player.owned_units

	if player.remote then
		Managers.state.event:trigger("remote_player_destroyed", player)
	end

	for unit, _ in pairs(owned_units) do
		self:relinquish_unit_ownership(unit)
	end

	self._players[player_index] = nil

	player:destroy()
end

PlayerManager.player_from_network_id = function (self, network_id)
	for player_index, player in pairs(self._players) do
		if network_id == player:network_id() then
			return player
		end
	end
end

PlayerManager.players = function (self)
	return self._players
end

PlayerManager.destroy = function (self)
	self:init()
end

PostmanPlayer = class(PostmanPlayer, Player)

PostmanPlayer.init = function (self, coat_of_arms, ...)
	PostmanPlayer.super.init(self, ...)

	self.spawn_data = {
		spawns = 0,
		state = "not_spawned"
	}
	self.local_player = true
	self.team = nil
	self.game_object_id = nil
	self.temp_random_user_id = nil
	self.camera_follow_unit = nil
	self.player_unit = nil
	self.coat_of_arms = coat_of_arms
	self.state_data = {
		visor_open = true,
		spawn_profile_selectable = false,
		objectives_blackboard = {}
	}
	self.ping_data = {
		mean_ping = 0,
		ping_table_index = 0,
		ping_table = {}
	}

	if not Managers.lobby.lobby then
		self.temp_random_user_id = self.index

		Managers.state.event:trigger("local_player_created", self)
	end

	self._alive = true
end

PostmanPlayer.alive = function (self)
	return self._alive
end

PostmanPlayer.create_camera_game_object = function (self, game)
	local camera_manager = Managers.state.camera
	local viewport_name = self.viewport_name
	local network_manager = Managers.state.network
	local game_object_data_table = {
		owner_destroy_func = NetworkLookup.game_object_functions.cb_do_nothing,
		object_destroy_func = NetworkLookup.game_object_functions.cb_camera_game_object_destroyed,
		game_object_created_func = NetworkLookup.game_object_functions.cb_camera_game_object_created,
		player_id = self.temp_random_user_id,
		position = camera_manager:camera_position(viewport_name),
		rotation = camera_manager:camera_rotation(viewport_name)
	}
	local callback = callback(self, "cb_game_session_disconnect")

	self.camera_game_object_id = network_manager:create_player_game_object("player_camera", game_object_data_table, callback)
end

PostmanPlayer.update_camera_game_object = function (self, position, rotation)
	local obj_id = self.camera_game_object_id
	local game = Managers.state.network:game()

	if obj_id and game then
		local networked_pos = Vector3(math.clamp(position.x, NetworkConstants.position.min, NetworkConstants.position.max), math.clamp(position.y, NetworkConstants.position.min, NetworkConstants.position.max), math.clamp(position.z, NetworkConstants.position.min, NetworkConstants.position.max))

		GameSession.set_game_object_field(game, obj_id, "position", networked_pos)
		GameSession.set_game_object_field(game, obj_id, "rotation", rotation)
	end
end

PostmanPlayer.create_game_object = function (self)
	local game_object_data_table = {
		tagged_player_object_id = 0,
		spawn_timer = 0,
		tagged_objective_level_id = 0,
		ping = 0,
		owner_destroy_func = NetworkLookup.game_object_functions.cb_do_nothing,
		object_destroy_func = NetworkLookup.game_object_functions.cb_player_game_object_destroyed,
		game_object_created_func = NetworkLookup.game_object_functions.cb_player_game_object_created,
		local_id = self.index,
		network_id = self:network_id()
	}

	if script_data.network_debug then
		print("Player:create_game_object( )", self.temp_random_user_id)
	end

	local callback = callback(self, "cb_game_session_disconnect")
	local game_object_id = Managers.state.network:create_player_game_object("player", game_object_data_table, callback)

	self.game_object_id = game_object_id
	self.temp_random_user_id = game_object_id

	self:create_coat_of_arms_game_object()
	Managers.state.event:trigger("local_player_created", self)
	self:create_stat_game_object()
end

PostmanPlayer.create_stat_game_object = function (self)
	local game_object_data_table = {
		game_object_created_func = NetworkLookup.game_object_functions.cb_player_stats_created,
		object_destroy_func = NetworkLookup.game_object_functions.cb_player_stats_destroyed,
		owner_destroy_func = NetworkLookup.game_object_functions.cb_do_nothing,
		player_id = self:player_id()
	}

	for _, stat_name in pairs(StatsSynchronizer.STATS_TO_SYNC) do
		game_object_data_table[stat_name] = Managers.state.stats_collection:get(self:network_id(), stat_name)
	end

	local callback = callback(self, "cb_game_session_disconnect")

	self.stat_game_object_id = Managers.state.network:create_game_object("player_stats", game_object_data_table, callback)
end

PostmanPlayer.set_stat_game_object = function (self, game_object_id, network_game)
	self.stat_game_object_id = game_object_id

	if game_object_id then
		Managers.state.event:trigger("player_stats_object_created", network_game, self, game_object_id)
	end
end

PostmanPlayer.create_coat_of_arms_game_object = function (self)
	local coat_of_arms = self.coat_of_arms
	local game_object_data_table = {
		owner_destroy_func = NetworkLookup.game_object_functions.cb_do_nothing,
		object_destroy_func = NetworkLookup.game_object_functions.cb_do_nothing,
		game_object_created_func = NetworkLookup.game_object_functions.cb_coat_of_arms_created,
		player_id = self:player_id(),
		field_color = NetworkLookup.coat_of_arms_field_colors[coat_of_arms.field_color],
		division_color = NetworkLookup.coat_of_arms_division_colors[coat_of_arms.division_color],
		division_type = NetworkLookup.coat_of_arms_division_types[coat_of_arms.division_type],
		variation_1_color = NetworkLookup.coat_of_arms_variation_colors[coat_of_arms.variation_1_color],
		variation_2_color = NetworkLookup.coat_of_arms_variation_colors[coat_of_arms.variation_2_color],
		variation_1_type = NetworkLookup.coat_of_arms_variation_types[coat_of_arms.variation_1_type],
		variation_2_type = NetworkLookup.coat_of_arms_variation_types[coat_of_arms.variation_2_type],
		ordinary_color = NetworkLookup.coat_of_arms_ordinary_colors[coat_of_arms.ordinary_color],
		ordinary_type = NetworkLookup.coat_of_arms_ordinary_types[coat_of_arms.ordinary_type],
		charge_color = NetworkLookup.coat_of_arms_charge_colors[coat_of_arms.charge_color],
		charge_type = NetworkLookup.coat_of_arms_charge_types[coat_of_arms.charge_type],
		crest = NetworkLookup.coat_of_arms_crests[coat_of_arms.crest]
	}

	if script_data.network_debug then
		print("PostmanPlayer:create_coat_of_arms_game_object( )", self.temp_random_user_id)
	end

	local callback = callback(self, "cb_game_session_disconnect")

	self.coat_of_arms_game_object_id = Managers.state.network:create_game_object("coat_of_arms", game_object_data_table, callback)
end

PostmanPlayer.cb_game_session_disconnect = function (self)
	self.game_object_id = nil
	self.camera_game_object_id = nil
	self.stat_game_object_id = nil
end

PostmanPlayer.set_team = function (self, team)
	self.team = team

	Managers.state.event:trigger("team_set", self)
end

PostmanPlayer.network_id = function (self)
	return not Managers.lobby.lobby and self:player_id() or Network.peer_id()
end

PostmanPlayer.set_game_object_id = function (self, id)
	self.game_object_id = id
	self.temp_random_user_id = id

	Managers.state.event:trigger("local_player_created", self)
end

PostmanPlayer.name = function (self)
	if not Managers.lobby.lobby then
		return "Player " .. self.index
	else
		return GameSettingsDevelopment.network_mode == "steam" and not script_data.settings.dedicated_server and Steam.user_name(self:network_id()) or "Player " .. self.index
	end
end

PostmanPlayer.player_id = function (self)
	return self.temp_random_user_id
end

PostmanPlayer.destroy = function (self)
	self._alive = false

	if Managers.state.network and Managers.lobby.server then
		if self.game_object_id then
			Managers.state.network:destroy_game_object(self.game_object_id)
		end

		if self.camera_game_object_id then
			Managers.state.network:destroy_game_object(self.camera_game_object_id)
		end

		if self.stat_game_object_id then
			Managers.state.network:destroy_game_object(self.stat_game_object_id)
		end
	end
end

RemotePlayer = class(RemotePlayer)

RemotePlayer.init = function (self, local_id, temp_random_user_id, peer, backend_profile_id, is_demo)
	self.remote = true
	self.peer_id = peer
	self.local_id = local_id
	self.owned_units = {}
	self.spawn_timer = 0.5
	self.team = nil
	self.game_object_id = nil
	self.backend_profile_id = backend_profile_id
	self.is_demo = is_demo
	self.spawn_data = {
		spawns = 0,
		state = "not_spawned"
	}
	self.ping_data = {
		mean_ping = 0,
		ping_table_index = 0,
		ping_table = {}
	}

	if temp_random_user_id then
		self.temp_random_user_id = temp_random_user_id

		self:set_game_object_id(temp_random_user_id)
	else
		self:create_game_object()
	end

	self.index = self.temp_random_user_id
	self.coat_of_arms = nil
	self._alive = true
end

RemotePlayer.alive = function (self)
	return self._alive
end

RemotePlayer.network_id = function (self)
	return self.peer_id
end

RemotePlayer.name = function (self)
	local network_id = self:network_id()
	local name

	if GameSettingsDevelopment.network_mode == "steam" then
		if script_data.settings.dedicated_server then
			local lobby = Managers.lobby.lobby

			if lobby then
				name = SteamGameServer.name(lobby, network_id)
			else
				name = tostring(self.index)
			end
		else
			name = Steam.user_name(network_id)
		end
	else
		name = tostring(self.index)
	end

	if string.len(name) < 3 then
		return "Desdichado"
	else
		return name
	end
end

RemotePlayer.destroy = function (self)
	self._alive = false

	if Managers.state.network and Managers.lobby.server then
		if self.game_object_id then
			Managers.state.network:destroy_game_object(self.game_object_id)
		end

		if self.stat_game_object_id then
			Managers.state.network:destroy_game_object(self.stat_game_object_id)
		end
	end
end

RemotePlayer.set_team = function (self, team)
	self.team = team

	Managers.state.event:trigger("team_set", self)
end

RemotePlayer.set_coat_of_arms = function (self, coat_of_arms)
	self.coat_of_arms = coat_of_arms
end

RemotePlayer.create_game_object = function (self)
	local game_object_data_table = {
		tagged_player_object_id = 0,
		spawn_timer = 0,
		tagged_objective_level_id = 0,
		ping = 0,
		owner_destroy_func = NetworkLookup.game_object_functions.cb_do_nothing,
		object_destroy_func = NetworkLookup.game_object_functions.cb_player_game_object_destroyed,
		game_object_created_func = NetworkLookup.game_object_functions.cb_player_game_object_created,
		network_id = self:network_id(),
		local_id = self.local_id
	}
	local callback = callback(self, "cb_game_session_disconnect")

	self.game_object_id = Managers.state.network:create_player_game_object("player", game_object_data_table, callback)
	self.temp_random_user_id = self.game_object_id

	if script_data.network_debug then
		print("RemotePlayer:create_game_object( )", self.temp_random_user_id)
	end

	Managers.state.event:trigger("remote_player_created", self)
	self:create_stat_game_object()
end

RemotePlayer.create_stat_game_object = function (self)
	local game_object_data_table = {
		game_object_created_func = NetworkLookup.game_object_functions.cb_player_stats_created,
		object_destroy_func = NetworkLookup.game_object_functions.cb_player_stats_destroyed,
		owner_destroy_func = NetworkLookup.game_object_functions.cb_do_nothing,
		player_id = self:player_id()
	}

	for _, stat_name in pairs(StatsSynchronizer.STATS_TO_SYNC) do
		game_object_data_table[stat_name] = Managers.state.stats_collection:get(self:network_id(), stat_name)
	end

	local callback = callback(self, "cb_game_session_disconnect")

	self.stat_game_object_id = Managers.state.network:create_game_object("player_stats", game_object_data_table, callback)
end

RemotePlayer.set_stat_game_object = function (self, game_object_id, network_game)
	self.stat_game_object_id = game_object_id

	if game_object_id then
		Managers.state.event:trigger("player_stats_object_created", network_game, self, game_object_id)
	end
end

RemotePlayer.cb_game_session_disconnect = function (self)
	self.game_object_id = nil
end

RemotePlayer.set_game_object_id = function (self, id)
	self.game_object_id = id

	Managers.state.event:trigger("remote_player_created", self)
end

RemotePlayer.set_camera_game_object_id = function (self, id)
	self.camera_game_object_id = id
end

RemotePlayer.player_id = function (self)
	return self.temp_random_user_id
end

AIPlayer = class(AIPlayer, PostmanPlayer)

AIPlayer.init = function (self, player_index)
	self.index = player_index
	self.team = nil
	self.game_object_id = nil
	self.spawn_timer = 3
	self.owned_units = {}
	self.ai_player = true
	self.temp_random_user_id = math.floor(Math.random() * 30000 + 5)
	self.spawn_data = {}
	self.state_data = {
		spawn_profile = "light_man_01"
	}
	self.coat_of_arms = DefaultCoatOfArms
	self._alive = true
end

AIPlayer.alive = function (self)
	return self._alive
end

AIPlayer.name = function (self)
	return "AI " .. tostring(self.team)
end

AIPlayer.network_id = function (self)
	return not Managers.lobby.lobby and self:player_id() or Network.peer_id()
end

AIPlayer.set_team = function (self, team)
	self.team = team
end

AIPlayer.create_game_object = function (self)
	local game_object_data_table = {
		score = 0,
		spawn_timer = 0,
		tagged_objective_level_id = 0,
		ping = 0,
		tagged_player_object_id = 0,
		owner_destroy_func = NetworkLookup.game_object_functions.cb_do_nothing,
		object_destroy_func = NetworkLookup.game_object_functions.cb_player_game_object_destroyed,
		game_object_created_func = NetworkLookup.game_object_functions.cb_player_game_object_created,
		player_id = self.temp_random_user_id,
		network_id = self:network_id()
	}

	if script_data.network_debug then
		print("RemotePlayer:create_game_object( )", self.temp_random_user_id)
	end

	local callback = callback(self, "cb_game_session_disconnect")

	self.game_object_id = Managers.state.network:create_player_game_object("player", game_object_data_table, callback)

	self:create_coat_of_arms_game_object()
end

AIPlayer.cb_game_session_disconnect = function (self)
	self.game_object_id = nil
end

AIPlayer.set_game_object_id = function (self, id)
	self.game_object_id = id
end

AIPlayer.player_id = function (self)
	return self.temp_random_user_id
end

AIPlayer.destroy = function (self)
	self._alive = false

	if Managers.state.network and Managers.lobby.server and self.game_object_id then
		Managers.state.network:destroy_game_object(self.game_object_id)
	end
end
