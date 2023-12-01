-- chunkname: @scripts/managers/network/game_network_manager.lua

require("scripts/network_lookup/network_lookup")

GameNetworkManager = class(GameNetworkManager)

local PING_SAMPLES_MAX_SIZE = 10
local PING_SAMPLE_INTERVAL = 1

GameNetworkManager.init = function (self, state, world, lobby)
	self._state = state
	self._world = world
	self._game = nil
	self._lobby = lobby
	self._units = {}
	self._owners = {}
	self._game_started = false
	self._left_game = false
	self._join_lobby_failed = false
	self._exit_to_menu_lobby = false
	self._next_level_settings = nil
	self._migrate_to_me_stack = nil
	self._game_object_types = {}
	self._object_synchronizing_clients = {}
	self._game_object_disconnect_callbacks = {}

	if self._lobby then
		Network.set_pong_timeout(GameSettingsDevelopment.network_timeout)
		dofile("scripts/network_lookup/network_constants")
	end

	self._ping_sample_time = 0

	Managers.chat:register_chat_rpc_callbacks(self)
end

GameNetworkManager.update = function (self, dt)
	Network.update(dt, self)

	if not self._lobby then
		return
	end

	if Managers.lobby.state == LobbyState.JOINED and not self._game and Managers.lobby.server and not self._left_game then
		local game = Network.create_game_session()

		UnitSynchronizer.set_world(GameSession.unit_synchronizer(game), self._world)
		GameSession.make_game_session_host(game)
		self:_send_game_server_set(true)

		self._game_started = true
		self._game = game
	elseif Managers.lobby.state == LobbyState.JOINED and not self._game and Managers.lobby:game_server_set() and not self._left_game then
		local game = Network.create_game_session()

		UnitSynchronizer.set_world(GameSession.unit_synchronizer(game), self._world)

		local player = Managers.player:player(1)
		local profile_id = Managers.persistence:profile_id()

		self:send_rpc_server("rpc_drop_in", player.index, profile_id, IS_DEMO, Postman.anti_cheat_key)

		self._game = game
	elseif Managers.lobby.state == LobbyState.FAILED then
		self._join_lobby_failed = true
	end

	if self._migrate_game_object_stack then
		for _, config in ipairs(self._migrate_game_object_stack) do
			GameSession.migrate_game_object(self._game, config.object_id, config.player_id, self)
		end

		self._migrate_game_object_stack = nil
	end

	if self._game_started and self._game then
		local broken = GameSession.broken_connection(self._game)

		if broken and Managers.lobby.server then
			self:remove(broken)
		end
	end

	if Managers.lobby.server and self._game_started and self._game then
		local left = GameSession.wants_to_leave(self._game)

		if left then
			self:remove(left)
		end
	end

	if self._game and self._game_session_disconnect then
		Network.shutdown_game_session()

		self._game = nil
		self._left_game = true
	end

	if Managers.lobby.server and self:game() then
		local t = Managers.time:time("round")

		if t and t > self._ping_sample_time then
			self:_sample_ping()

			self._ping_sample_time = t + PING_SAMPLE_INTERVAL
		end

		self:_sync_mean_ping()
	end
end

GameNetworkManager._sample_ping = function (self)
	for player_index, player in pairs(Managers.player:players()) do
		if player.remote then
			local ping_data = player.ping_data

			ping_data.ping_table_index = ping_data.ping_table_index % PING_SAMPLES_MAX_SIZE + 1
			ping_data.ping_table[ping_data.ping_table_index] = Network.ping(player:network_id())
			ping_data.mean_ping = self:_calculate_mean_ping(ping_data.ping_table)
		end
	end
end

GameNetworkManager._calculate_mean_ping = function (self, ping_table)
	local ping_sum = 0

	for _, ping in ipairs(ping_table) do
		ping_sum = ping_sum + ping
	end

	return math.ceil(ping_sum / #ping_table * 1000)
end

GameNetworkManager._sync_mean_ping = function (self)
	for player_index, player in pairs(Managers.player:players()) do
		if not player.ai_player and player.game_object_id then
			local mean_ping = math.clamp(player.ping_data.mean_ping, NetworkConstants.ping.min, NetworkConstants.ping.max)

			GameSession.set_game_object_field(self:game(), player.game_object_id, "ping", mean_ping)
		end
	end
end

GameNetworkManager._send_game_server_set = function (self, is_set)
	local lobby_members = Managers.lobby:lobby_members()

	for _, member in pairs(lobby_members) do
		if member ~= Network.peer_id() then
			RPC.rpc_game_server_set(member, is_set)
		end
	end

	Managers.lobby:set_game_server(is_set and Network.peer_id() or nil)
end

GameNetworkManager.rpc_player_killed_by_enemy = function (self, sender, own_player_id, attacking_player_id)
	local own_player = Managers.player:player(self:temp_player_index(own_player_id))
	local attacking_player = Managers.player:player(self:temp_player_index(attacking_player_id))

	Managers.state.event:trigger("player_killed_by_enemy", own_player, attacking_player)
end

GameNetworkManager.rpc_synch_unit_damage_level = function (self, sender, game_object_id, damage_level, dead)
	local level = LevelHelper:current_level(self._world)
	local unit_index = GameSession.game_object_field(self._game, game_object_id, "unit_game_object_id")
	local unit = Level.unit_by_index(level, unit_index)
	local extension = ScriptUnit.extension(unit, "damage_system")

	extension:rpc_synch_unit_damage_level(damage_level, dead)
end

GameNetworkManager.rpc_climb_ladder = function (self, sender, unit_id, ladder_lvl_id)
	local unit = self._units[unit_id]
	local level = LevelHelper:current_level(self._world)
	local ladder_unit = Level.unit_by_index(level, ladder_lvl_id)

	if Unit.alive(unit) and Unit.alive(ladder_unit) then
		if Managers.lobby.server then
			self:send_rpc_clients_except("rpc_climb_ladder", sender, unit_id, ladder_lvl_id)
		end

		ScriptUnit.extension(unit, "locomotion_system"):set_ladder_unit(ladder_unit)
	end
end

GameNetworkManager.rpc_link_projectile_obj_id = function (self, sender, unit_hit_id, node_index, projectile_id, position, rotation, damage, penetrated, target_type_id, hit_zone_id, impact_direction, normal)
	local hit_unit = self._units[unit_hit_id]
	local projectile_unit = self._units[projectile_id]

	if not hit_unit or not Unit.alive(hit_unit) or not projectile_unit or not Unit.alive(projectile_unit) then
		return
	end

	if Managers.lobby.server then
		self:send_rpc_clients("rpc_link_projectile_obj_id", unit_hit_id, node_index, projectile_id, position, rotation, damage, penetrated, target_type_id, hit_zone_id, impact_direction, normal)
	end

	local target_type = NetworkLookup.weapon_hit_parameters[target_type_id]

	Managers.state.projectile:link_projectile(hit_unit, node_index, position, rotation, damage, penetrated, target_type, projectile_unit, false, NetworkLookup.hit_zones[hit_zone_id], impact_direction, normal)
end

GameNetworkManager.rpc_remove_projectiles = function (self, sender, player_index)
	Managers.state.projectile:remove_projectiles(player_index)
end

GameNetworkManager.rpc_link_projectile_lvl_id = function (self, sender, unit_lvl_id, node_index, projectile_id, position, rotation, damage, penetrated, target_type_id, hit_zone_id, impact_direction, normal)
	local level = LevelHelper:current_level(self._world)
	local hit_unit = Level.unit_by_index(level, unit_lvl_id)
	local projectile_unit = self._units[projectile_id]

	if not hit_unit or not Unit.alive(hit_unit) or not projectile_unit or not Unit.alive(projectile_unit) then
		return
	end

	if Managers.lobby.server then
		self:send_rpc_clients("rpc_link_projectile_lvl_id", unit_lvl_id, node_index, projectile_id, position, rotation, damage, penetrated, target_type_id, hit_zone_id, impact_direction, normal)
	end

	local target_type = NetworkLookup.weapon_hit_parameters[target_type_id]

	Managers.state.projectile:link_projectile(hit_unit, node_index, position, rotation, damage, penetrated, target_type, projectile_unit, false, NetworkLookup.hit_zones[hit_zone_id], impact_direction, normal)
end

GameNetworkManager.rpc_drop_projectile_obj_id = function (self, sender, unit_hit_id, projectile_id, position, rotation, damage, penetrated, target_type_id, hit_zone_id, impact_direction, normal)
	local hit_unit = self._units[unit_hit_id]
	local projectile_unit = self._units[projectile_id]

	if not hit_unit or not Unit.alive(hit_unit) or not projectile_unit or not Unit.alive(projectile_unit) then
		return
	end

	if Managers.lobby.server then
		self:send_rpc_clients("rpc_drop_projectile_obj_id", unit_hit_id, projectile_id, position, rotation, damage, penetrated, target_type_id, hit_zone_id, impact_direction, normal)
	end

	local target_type = NetworkLookup.weapon_hit_parameters[target_type_id]

	Managers.state.projectile:drop_projectile(hit_unit, position, rotation, damage, penetrated, target_type, projectile_unit, false, NetworkLookup.hit_zones[hit_zone_id], impact_direction, normal)
end

GameNetworkManager.rpc_drop_projectile_lvl_id = function (self, sender, unit_lvl_id, projectile_id, position, rotation, damage, penetrated, target_type_id, hit_zone_id, impact_direction, normal)
	local level = LevelHelper:current_level(self._world)
	local hit_unit = Level.unit_by_index(level, unit_lvl_id)
	local projectile_unit = self._units[projectile_id]

	if not hit_unit or not Unit.alive(hit_unit) or not projectile_unit or not Unit.alive(projectile_unit) then
		return
	end

	if Managers.lobby.server then
		self:send_rpc_clients("rpc_drop_projectile_lvl_id", unit_lvl_id, projectile_id, position, rotation, damage, penetrated, target_type_id, hit_zone_id, impact_direction, normal)
	end

	local target_type = NetworkLookup.weapon_hit_parameters[target_type_id]

	Managers.state.projectile:drop_projectile(hit_unit, position, rotation, damage, penetrated, target_type, projectile_unit, false, NetworkLookup.hit_zones[hit_zone_id], impact_direction, normal)
end

GameNetworkManager.rpc_activate_spawn_area = function (self, sender, spawn_area_id, team_name_id)
	local spawn_area_name = Managers.state.spawn:network_lookup_to_area_name(spawn_area_id)
	local team_name = NetworkLookup.team[team_name_id]

	Managers.state.spawn:activate_spawn_area(spawn_area_name, team_name, Vector3.right())
end

GameNetworkManager.rpc_deactivate_spawn_area = function (self, sender, spawn_area_id, team_name_id)
	local spawn_area_name = Managers.state.spawn:network_lookup_to_area_name(spawn_area_id)
	local team_name = NetworkLookup.team[team_name_id]

	Managers.state.spawn:deactivate_spawn_area(spawn_area_name, team_name)
end

GameNetworkManager.rpc_set_spawn_area_priority = function (self, sender, spawn_area_id, team_name_id, priority)
	local spawn_area_name = Managers.state.spawn:network_lookup_to_area_name(spawn_area_id)
	local team_name = NetworkLookup.team[team_name_id]

	Managers.state.spawn:set_spawn_area_priority(spawn_area_name, team_name, priority)
end

GameNetworkManager.rpc_execute_request = function (self, sender, attacker_id, victim_id, execution_id)
	local attacker_unit = self._units[attacker_id]
	local victim_unit = self._units[victim_id]

	if Unit.alive(victim_unit) and Unit.alive(attacker_unit) then
		local damage_ext = ScriptUnit.extension(victim_unit, "damage_system")
		local can_be_executed = damage_ext:can_be_executed()

		if can_be_executed then
			InteractionHelper:confirm_request("execute", sender, attacker_id)
			damage_ext:start_execution(attacker_id, Managers.player:owner(attacker_unit))
			self:send_rpc_clients_except("rpc_play_execution_anims", sender, attacker_id, victim_id, execution_id)

			local network_self = Network.peer_id()

			if sender ~= network_self then
				local execution_definition = ExecutionDefinitions[NetworkLookup.executions[execution_id]]

				ScriptUnit.extension(attacker_unit, "locomotion_system"):start_execution_attacker(execution_definition, victim_unit)
				ScriptUnit.extension(victim_unit, "locomotion_system"):start_execution_victim(execution_definition, attacker_unit)
			end

			return
		end
	end

	InteractionHelper:deny_request("execute", sender, attacker_id)
end

GameNetworkManager.rpc_play_execution_anims = function (self, sender, attacker_id, victim_id, execution_id)
	local attacker_unit = self._units[attacker_id]
	local victim_unit = self._units[victim_id]

	if Unit.alive(victim_unit) and Unit.alive(attacker_unit) then
		local execution_definition = ExecutionDefinitions[NetworkLookup.executions[execution_id]]

		ScriptUnit.extension(attacker_unit, "locomotion_system"):start_execution_attacker(execution_definition, victim_unit)
		ScriptUnit.extension(victim_unit, "locomotion_system"):start_execution_victim(execution_definition, attacker_unit)
	end
end

GameNetworkManager.rpc_execute_abort = function (self, sender, attacker_id, victim_id)
	local victim_unit = self._units[victim_id]

	if victim_unit and Unit.alive(victim_unit) then
		local damage_ext = ScriptUnit.extension(victim_unit, "damage_system")

		if damage_ext:abort_execution(attacker_id) then
			self:send_rpc_clients("rpc_play_execution_abort_anim", victim_id)
			ScriptUnit.extension(victim_unit, "locomotion_system"):abort_execution_victim()
		end
	end
end

GameNetworkManager.rpc_play_execution_abort_anim = function (self, sender, victim_id)
	local victim_unit = self._units[victim_id]

	if victim_unit and Unit.alive(victim_unit) then
		ScriptUnit.extension(victim_unit, "locomotion_system"):abort_execution_victim()
	end
end

GameNetworkManager.rpc_execute_complete = function (self, sender, attacker_id, victim_id)
	return
end

GameNetworkManager.rpc_execute_confirmed = function (self, sender, attacker_id, victim_id)
	local executor_unit = self._units[attacker_id]

	InteractionHelper:confirmed("execute", ScriptUnit.extension(executor_unit, "locomotion_system"))
end

GameNetworkManager.rpc_execute_denied = function (self, sender, attacker_id, victim_id)
	local executor_unit = self._units[attacker_id]

	InteractionHelper:denied("execute", ScriptUnit.extension(executor_unit, "locomotion_system"))
end

GameNetworkManager.rpc_yield_request = function (self, sender, unit_id)
	local unit = self._units[unit_id]

	if unit and Unit.alive(unit) then
		local damage_ext = ScriptUnit.extension(unit, "damage_system")
		local can_yield = damage_ext:can_yield()

		if can_yield then
			local self_peer_id = Network.peer_id()

			if sender == self_peer_id then
				InteractionHelper:confirmed("yield", ScriptUnit.extension(unit, "locomotion_system"))
			else
				InteractionHelper:confirm_request("yield", sender, unit_id)
			end

			damage_ext:yield()

			return
		end
	end

	InteractionHelper:deny_request("yield", sender, unit_id)
end

GameNetworkManager.rpc_yield_denied = function (self, sender, unit_id)
	local unit = self._units[unit_id]

	InteractionHelper:denied("yield", ScriptUnit.extension(unit, "locomotion_system"))
end

GameNetworkManager.rpc_yield_confirmed = function (self, sender, unit_id)
	local unit = self._units[unit_id]

	InteractionHelper:confirmed("yield", ScriptUnit.extension(unit, "locomotion_system"))
end

GameNetworkManager._shutdown_server = function (self)
	for _, player in ipairs(GameSession.other_peers(self._game)) do
		self:remove(player, true)
	end

	self:game_session_disconnect()

	for game_object_id, owner_id in pairs(self._owners) do
		if Network.peer_id() ~= owner_id then
			self:game_object_destroyed(game_object_id, owner_id)
		end
	end

	GameSession.shutdown_game_session_host(self._game)
	Network.shutdown_game_session()
	self:_send_game_server_set(false)

	self._game = nil
	self._left_game = true
end

GameNetworkManager.leave_game = function (self)
	if Managers.lobby.server then
		self:_shutdown_server()
	else
		GameSession.leave(self._game)
	end
end

GameNetworkManager.exit_all_to_menu_lobby = function (self)
	if Managers.lobby.server then
		self:send_rpc_clients("rpc_exit_to_menu_lobby")

		self._exit_to_menu_lobby = true

		self:_shutdown_server()
	else
		assert(false, "Only server can exit all players to menu lobby!")
	end
end

GameNetworkManager.reload_level = function (self, level_key, game_mode_key, win_score, time_limit)
	local lobby_manager = Managers.lobby

	if lobby_manager.server then
		local game_server_settings = lobby_manager.game_server_settings
		local game_start_countdown = game_server_settings and game_server_settings.game_start_countdown or GameSettingsDevelopment.game_start_countdown

		self._next_level_settings = "reload_level"

		local own_peer_id = Network.peer_id()

		for _, member in ipairs(Managers.lobby:lobby_members()) do
			if member ~= own_peer_id then
				RPC.rpc_reload_level(member)
			end
		end

		self:_shutdown_server()
	else
		assert(false, "Only server can initiate reloading level!")
	end
end

GameNetworkManager.rpc_reload_level = function (self, sender)
	self._next_level_settings = "reload_level"

	print("reload_level", sender)
end

GameNetworkManager.load_next_level = function (self, level_key, game_mode_key, win_score, time_limit)
	local lobby_manager = Managers.lobby

	if lobby_manager.server then
		local game_server_settings = lobby_manager.game_server_settings
		local game_start_countdown = game_server_settings and game_server_settings.game_start_countdown or GameSettingsDevelopment.game_start_countdown

		self._next_level_settings = {
			level_key = level_key,
			game_mode_key = game_mode_key,
			game_start_countdown = game_start_countdown,
			win_score = win_score,
			time_limit = time_limit
		}

		local level = LevelSettings[level_key]
		local map = level.game_server_map_name

		lobby_manager:set_lobby_data("map", map)

		if lobby_manager:is_dedicated_server() then
			lobby_manager:set_game_tag("game_mode_key", game_mode_key)
		end

		lobby_manager:set_lobby_data("level_key", level_key)
		lobby_manager:set_lobby_data("game_mode_key", game_mode_key)
		lobby_manager:set_lobby_data("win_score", win_score)
		lobby_manager:set_lobby_data("time_limit", time_limit)

		for _, member in ipairs(Managers.lobby:lobby_members()) do
			if member ~= Network.peer_id() then
				RPC.rpc_load_next_level(member, NetworkLookup.level_keys[level_key], NetworkLookup.game_mode_keys[game_mode_key], game_start_countdown, win_score, time_limit)
			end
		end

		self:_shutdown_server()
	else
		assert(false, "Only server can initiate loading of next level!")
	end
end

GameNetworkManager.rpc_exit_to_menu_lobby = function (self)
	self._exit_to_menu_lobby = true
end

GameNetworkManager.rpc_load_next_level = function (self, sender, level_key, game_mode_key, game_start_countdown, win_score, time_limit)
	self._next_level_settings = {
		level_key = NetworkLookup.level_keys[level_key],
		game_mode_key = NetworkLookup.game_mode_keys[game_mode_key],
		game_start_countdown = game_start_countdown,
		win_score = win_score,
		time_limit = time_limit
	}
end

GameNetworkManager.exit_to_menu_lobby = function (self)
	return self._exit_to_menu_lobby
end

GameNetworkManager.has_left_game = function (self)
	return self._left_game
end

GameNetworkManager.join_lobby_failed = function (self)
	return self._join_lobby_failed
end

GameNetworkManager.next_level_settings = function (self)
	return self._next_level_settings
end

GameNetworkManager.destroy = function (self)
	if self._lobby then
		NetworkConstants = nil
	end
end

GameNetworkManager.game = function (self)
	return self._game_started and self._game
end

GameNetworkManager.game_object_owner = function (self, obj_id)
	return self._owners[obj_id]
end

GameNetworkManager.game_object_id = function (self, unit)
	return Unit.get_data(unit, "game_object_id")
end

GameNetworkManager.level_object_id = function (self, unit)
	local current_level = LevelHelper:current_level(self._world)

	return Level.unit_index(current_level, unit)
end

GameNetworkManager.unit_game_object_id = function (self, unit)
	if Unit.has_data(unit, "game_object_id") then
		return Unit.get_data(unit, "game_object_id")
	end
end

GameNetworkManager.game_object_unit = function (self, obj_id)
	return self._units[obj_id]
end

GameNetworkManager.create_game_object = function (self, object_template, data_table, local_object_destroy_callback, local_object_created_func, ...)
	if script_data.network_debug then
		print("CREATING GAME OBJECT")
	end

	local game_object_id = GameSession.create_game_object(self._game, object_template, data_table)

	self._game_object_types[game_object_id] = object_template
	self._game_object_disconnect_callbacks[game_object_id] = local_object_destroy_callback

	if local_object_created_func then
		self[local_object_created_func](self, game_object_id, ...)
	end

	if script_data.network_debug then
		print("GAME OBJECT CREATED", game_object_id)
		table.dump(data_table)
	end

	return game_object_id
end

GameNetworkManager.create_spawn_point_game_object = function (self, data_table)
	local game_object_id = GameSession.create_game_object(self._game, "spawn_point", data_table)

	self._game_object_types[game_object_id] = "spawn_point"

	if script_data.network_debug then
		print("CREATE GAME OBJECT id: " .. game_object_id .. " type: spawn_point")
	end

	return game_object_id
end

GameNetworkManager.create_player_game_object = function (self, profile, data_table, local_object_destroy_callback)
	local game_object_id = GameSession.create_game_object(self._game, profile, data_table)

	self._game_object_types[game_object_id] = "player"
	self._game_object_disconnect_callbacks[game_object_id] = local_object_destroy_callback

	if script_data.network_debug then
		print("CREATE GAME OBJECT id: " .. game_object_id .. " type: player")
		table.dump(data_table)
	end

	return game_object_id
end

GameNetworkManager.cb_spawn_point_game_object_created = function (self, game_object_id, owner_id)
	Managers.state.event:trigger("event_create_client_spawnpoint", game_object_id)

	if script_data.spawn_debug then
		print("spawn created", game_object_id)
	end
end

GameNetworkManager.cb_player_game_object_created = function (self, game_object_id, owner_id)
	local player_manager = Managers.player

	assert(not Managers.lobby.server, "cb_player_game_object_created: FAIL")

	if script_data.network_debug then
		print("cb_player_game_object_created", game_object_id, owner_id)
	end

	if script_data.network_debug then
		print("cb_player_game_object_created, player_id:", game_object_id)
	end

	local player_manager = Managers.player
	local players = player_manager:players()
	local max_players = player_manager.MAX_PLAYERS
	local peer_id = GameSession.game_object_field(self._game, game_object_id, "network_id")
	local local_id = GameSession.game_object_field(self._game, game_object_id, "local_id")

	if peer_id == Network.peer_id() then
		local player = player_manager:player(local_id)

		player:set_game_object_id(game_object_id)
		player:create_camera_game_object()
		player:create_coat_of_arms_game_object()
	else
		if script_data.network_debug then
			print("PLAYER ADDED " .. tostring(game_object_id))
		end

		player_manager:add_remote_player(local_id, game_object_id, peer_id)
	end
end

GameNetworkManager.cb_camera_game_object_destroyed = function (self, game_object_id, owner_id)
	if owner_id ~= Network.peer_id() then
		local player_manager = Managers.player
		local player_id = GameSession.game_object_field(self._game, game_object_id, "player_id")

		if not player_manager:player_exists(player_id) then
			return
		end

		local player = player_manager:player(player_id)

		player:set_camera_game_object_id(nil)
	end
end

GameNetworkManager.cb_camera_game_object_created = function (self, game_object_id, owner_id)
	local player_id = GameSession.game_object_field(self._game, game_object_id, "player_id")
	local player = Managers.player:player(player_id)

	player:set_camera_game_object_id(game_object_id)
end

GameNetworkManager.cb_player_game_object_destroyed = function (self, game_object_id, owner_id)
	local player_manager = Managers.player
	local player_id = game_object_id

	if not Managers.lobby.server and player_manager:player_exists(player_id) then
		player_manager:remove_player(player_id)
	end
end

GameNetworkManager.cb_player_stats_created = function (self, game_object_id, owner_id)
	local player_id = GameSession.game_object_field(self._game, game_object_id, "player_id")
	local player = Managers.player:player(self:temp_player_index(player_id))

	player:set_stat_game_object(game_object_id, self._game)
end

GameNetworkManager.cb_player_stats_destroyed = function (self, game_object_id, owner_id)
	if owner_id ~= Network.peer_id() then
		local player_id = GameSession.game_object_field(self._game, game_object_id, "player_id")

		if not Managers.player:player_exists(player_id) then
			return
		end

		local player = Managers.player:player(player_id)

		player:set_stat_game_object(nil)
	end
end

GameNetworkManager.cb_generic_unit_interactable_created = function (self, game_object_id, owner_id)
	local unit_level_object_id = GameSession.game_object_field(self._game, game_object_id, "level_unit_index")
	local level = LevelHelper:current_level(self._world)
	local unit = Level.unit_by_index(level, unit_level_object_id)
	local extension = ScriptUnit.extension(unit, "objective_system")

	extension:set_game_object_id(game_object_id, self._game)
end

GameNetworkManager.cb_generic_unit_interactable_destroyed = function (self, game_object_id, owner_id)
	local unit_level_object_id = GameSession.game_object_field(self._game, game_object_id, "level_unit_index")
	local level = LevelHelper:current_level(self._world)
	local unit = Level.unit_by_index(level, unit_level_object_id)
	local extension = ScriptUnit.extension(unit, "objective_system")

	extension:remove_game_object_id()
end

GameNetworkManager.cb_generic_damage_extension_game_object_created = function (self, game_object_id, owner_id)
	local unit_level_object_id = GameSession.game_object_field(self._game, game_object_id, "unit_game_object_id")
	local level = LevelHelper:current_level(self._world)
	local unit = Level.unit_by_index(level, unit_level_object_id)
	local damage_ext = ScriptUnit.extension(unit, "damage_system")

	damage_ext:set_game_object_id(game_object_id, self._game)
end

GameNetworkManager.cb_generic_damage_extension_game_object_destroyed = function (self, game_object_id, owner_id)
	local unit_level_object_id = GameSession.game_object_field(self._game, game_object_id, "unit_game_object_id")
	local level = LevelHelper:current_level(self._world)
	local unit = Level.unit_by_index(level, unit_level_object_id)

	if unit and Unit.alive(unit) then
		local damage_ext = ScriptUnit.extension(unit, "damage_system")

		damage_ext:remove_game_object_id()
	else
		Application.warning("Trying to destroy a game object for an unspawned unit!")
	end
end

GameNetworkManager.cb_player_damage_extension_game_object_created = function (self, game_object_id, owner_id)
	local unit_game_object_id = GameSession.game_object_field(self._game, game_object_id, "player_unit_game_object_id")
	local unit = self._units[unit_game_object_id]

	if script_data.network_debug then
		print("DAMAGE EXT HUSK SET GAME OBJECT", unit_game_object_id, game_object_id, unit)
	end

	if not Unit.alive(unit) then
		return
	end

	if not ScriptUnit.has_extension(unit, "damage_system") then
		return
	end

	local damage_ext = ScriptUnit.extension(unit, "damage_system")

	damage_ext:set_game_object_id(game_object_id, self._game)
end

GameNetworkManager.cb_player_damage_extension_game_object_destroyed = function (self, game_object_id, owner_id)
	local unit_game_object_id = GameSession.game_object_field(self._game, game_object_id, "player_unit_game_object_id")
	local unit = self._units[unit_game_object_id]

	if not Unit.alive(unit) then
		return
	end

	if script_data.network_debug then
		print("DAMAGE EXT HUSK REMOVE GAME OBJECT", unit_game_object_id, game_object_id, unit)
	end

	local damage_ext = ScriptUnit.extension(unit, "damage_system")

	damage_ext:remove_game_object_id(game_object_id, self._game)
end

GameNetworkManager.cb_area_buff_game_object_created = function (self, game_object_id, owner_id)
	local unit_game_object_id = GameSession.game_object_field(self._game, game_object_id, "player_unit_game_object_id")
	local unit = self._units[unit_game_object_id]

	if not Unit.alive(unit) then
		return
	end

	if not ScriptUnit.has_extension(unit, "area_buff_system") then
		return
	end

	local area_buff_ext = ScriptUnit.extension(unit, "area_buff_system")

	area_buff_ext:set_game_object_id(game_object_id, self._game)
end

GameNetworkManager.cb_area_buff_game_object_destroyed = function (self, game_object_id, owner_id)
	local unit_game_object_id = GameSession.game_object_field(self._game, game_object_id, "player_unit_game_object_id")
	local unit = self._units[unit_game_object_id]

	if not Unit.alive(unit) then
		return
	end

	local area_buff_ext = ScriptUnit.extension(unit, "area_buff_system")

	area_buff_ext:remove_game_object_id(game_object_id, self._game)
end

GameNetworkManager.cb_local_unit_spawned = function (self, obj_id, unit)
	self._units[obj_id] = unit
	self._owners[obj_id] = Network.peer_id()

	Unit.set_data(unit, "game_object_id", obj_id)
end

GameNetworkManager.game_object_created = function (self, game_object_id, owner_id)
	if script_data.network_debug then
		print("game object created", game_object_id, owner_id)
	end

	local id = GameSession.game_object_field(self._game, game_object_id, "game_object_created_func")
	local game_object_created_func = NetworkLookup.game_object_functions[id]

	if script_data.network_debug then
		print("calling game object func", game_object_created_func)
	end

	self[game_object_created_func](self, game_object_id, owner_id)
end

GameNetworkManager.cb_team_created = function (self, obj_id, owner_id)
	local team_manager = Managers.state.team
	local name = NetworkLookup.team[GameSession.game_object_field(self._game, obj_id, "name")]

	team_manager:cb_game_object_created(name, obj_id)
end

GameNetworkManager.cb_team_destroyed = function (self, obj_id, owner_id)
	local team_manager = Managers.state.team
	local name = NetworkLookup.team[GameSession.game_object_field(self._game, obj_id, "name")]

	team_manager:cb_game_object_destroyed(name, obj_id)
end

GameNetworkManager.cb_spawn_flag = function (self, obj_id, owner_id)
	local game = self._game
	local husk_unit = NetworkLookup.husks[GameSession.game_object_field(game, obj_id, "husk_unit")]
	local position = GameSession.game_object_field(game, obj_id, "position")
	local rotation = GameSession.game_object_field(game, obj_id, "rotation")

	if script_data.network_debug then
		print("spawning_flag_husk: ", husk_unit, position, rotation, game, obj_id, owner_id)
	end

	local unit = World.spawn_unit(self._world, husk_unit, position, rotation)

	Unit.set_data(unit, "game_object_id", obj_id)

	self._units[obj_id] = unit
	self._owners[obj_id] = owner_id

	Managers.state.entity:register_unit(self._world, unit, obj_id, game, owner_id)

	if script_data.network_debug then
		print("SPAWNING FLAG HUSK", obj_id)
	end

	local unit = self._units[obj_id]
	local objective_ext = ScriptUnit.extension(unit, "flag_system")

	objective_ext:set_game_object_id(obj_id, game)
end

GameNetworkManager.cb_spawn_unit = function (self, obj_id, owner_id)
	local husk_unit = NetworkLookup.husks[GameSession.game_object_field(self._game, obj_id, "husk_unit")]
	local position = GameSession.game_object_field(self._game, obj_id, "position")
	local rotation = GameSession.game_object_field(self._game, obj_id, "rotation")
	local ghost_mode = GameSession.game_object_field(self._game, obj_id, "ghost_mode")

	if script_data.network_debug then
		print("spawning_husk: ", husk_unit, position, rotation, self._game, obj_id, owner_id)
	end

	local unit = World.spawn_unit(self._world, husk_unit, position, rotation)

	Unit.set_data(unit, "game_object_id", obj_id)

	self._units[obj_id] = unit
	self._owners[obj_id] = owner_id

	Managers.state.entity:register_unit(self._world, unit, obj_id, self._game, ghost_mode)

	if script_data.network_debug then
		print("SPAWNING HUSK", obj_id)
	end
end

GameNetworkManager.cb_spawn_projectile = function (self, obj_id, owner_id)
	local game = self._game
	local husk_unit = NetworkLookup.husks[GameSession.game_object_field(game, obj_id, "husk_unit")]
	local position = GameSession.game_object_field(game, obj_id, "position")
	local projectile_name = NetworkLookup.projectiles[GameSession.game_object_field(game, obj_id, "projectile_name_id")]
	local gear_name = NetworkLookup.inventory_gear[GameSession.game_object_field(game, obj_id, "gear_name_id")]
	local exit_velocity = GameSession.game_object_field(game, obj_id, "exit_velocity")
	local user_object_id = GameSession.game_object_field(game, obj_id, "user_object_id")
	local weapon_object_id = GameSession.game_object_field(game, obj_id, "weapon_object_id")
	local player_index = GameSession.game_object_field(game, obj_id, "player_index")
	local gravity_multiplier = GameSession.game_object_field(game, obj_id, "gravity_multiplier")
	local damage_multiplier = GameSession.game_object_field(game, obj_id, "damage_multiplier")
	local properties_id = GameSession.game_object_field(game, obj_id, "properties_id")
	local user_unit = self._units[user_object_id]
	local weapon_unit = self._units[weapon_object_id]
	local rotation = Quaternion.look(exit_velocity, Vector3.up())
	local unit = World.spawn_unit(self._world, husk_unit, position, rotation)

	self._units[obj_id] = unit
	self._owners[obj_id] = owner_id

	Unit.set_data(unit, "game_object_id", obj_id)

	player_index = self:temp_player_index(player_index)

	Managers.state.entity:register_unit(self._world, unit, player_index, user_unit, weapon_unit, true, game, projectile_name, gear_name, exit_velocity, gravity_multiplier, damage_multiplier, properties_id)
end

GameNetworkManager.cb_spawn_gear = function (self, obj_id, owner_id)
	if script_data.network_debug then
		print("[GameNetworkManager] cb_spawn_gear")
	end

	local gear_name = NetworkLookup.inventory_gear[GameSession.game_object_field(self._game, obj_id, "gear_name")]
	local user_object_id = GameSession.game_object_field(self._game, obj_id, "user_object_id")
	local user_unit = self._units[user_object_id]

	if script_data.network_debug then
		print("   user unit:", tostring(user_unit), "user object id:", user_object_id)
	end

	local locomotion = ScriptUnit.extension(user_unit, "locomotion_system")

	if script_data.network_debug and locomotion then
		print("   locomotion system:", locomotion.SYSTEM)
	end

	local inventory = locomotion:inventory()
	local attachment_ids = {}

	for i = 1, NetworkConstants.max_attachments do
		local value = GameSession.game_object_field(self._game, obj_id, "att_id_" .. i)

		attachment_ids[i] = value
	end

	local unit = inventory:add_gear(gear_name, obj_id, attachment_ids)

	self._units[obj_id] = unit
	self._owners[obj_id] = owner_id

	Unit.set_data(unit, "game_object_id", obj_id)

	if Managers.lobby.server then
		local extensions = ScriptUnit.extension_definitions(unit)

		for _, extension in ipairs(extensions) do
			ScriptUnit.add_extension(self._world, unit, extension)
		end
	end
end

GameNetworkManager.cb_local_gear_unit_spawned = function (self, obj_id, unit)
	if script_data.network_debug then
		print("[GameNetworkManager] cb_local_gear_unit_spawned " .. tostring(unit))
	end

	self._units[obj_id] = unit
	self._owners[obj_id] = Network.peer_id()

	Unit.set_data(unit, "game_object_id", obj_id)

	if Managers.lobby.server then
		local extensions = ScriptUnit.extension_definitions(unit)

		for _, extension in ipairs(extensions) do
			ScriptUnit.add_extension(self._world, unit, extension)
		end
	end
end

GameNetworkManager.cb_capture_point_created = function (self, obj_id, owner_id)
	local game = self._game
	local level = LevelHelper:current_level(self._world)
	local level_unit_index = GameSession.game_object_field(game, obj_id, "level_unit_index")
	local unit = Level.unit_by_index(level, level_unit_index)

	self._units[obj_id] = unit
	self._owners[obj_id] = owner_id

	Unit.set_data(unit, "game_object_id", obj_id)

	local objective_ext = ScriptUnit.extension(unit, "objective_system")

	objective_ext:set_game_object_id(obj_id, game)
end

GameNetworkManager.cb_payload_created = function (self, obj_id, owner_id)
	local game = self._game
	local level = LevelHelper:current_level(self._world)
	local level_unit_index = GameSession.game_object_field(game, obj_id, "level_unit_index")
	local unit = Level.unit_by_index(level, level_unit_index)

	self._units[obj_id] = unit
	self._owners[obj_id] = owner_id

	Unit.set_data(unit, "game_object_id", obj_id)

	local objective_ext = ScriptUnit.extension(unit, "objective_system")

	objective_ext:set_game_object_id(obj_id, game)
end

GameNetworkManager.cb_local_payload_created = function (self, obj_id, unit)
	self._units[obj_id] = unit
	self._owners[obj_id] = Network.peer_id()

	Unit.set_data(unit, "game_object_id", obj_id)
end

GameNetworkManager.cb_local_capture_point_created = function (self, obj_id, unit)
	self._units[obj_id] = unit
	self._owners[obj_id] = Network.peer_id()

	Unit.set_data(unit, "game_object_id", obj_id)
end

GameNetworkManager.cb_payload_destroyed = function (self, obj_id)
	local unit = self._units[obj_id]

	if not Managers.lobby.server then
		local objective_ext = ScriptUnit.extension(unit, "objective_system")

		objective_ext:set_game_object_id(nil)
	end

	self._units[obj_id] = nil
	self._owners[obj_id] = nil
end

GameNetworkManager.cb_capture_point_destroyed = function (self, obj_id)
	local unit = self._units[obj_id]

	if not Managers.lobby.server then
		local objective_ext = ScriptUnit.extension(unit, "objective_system")

		objective_ext:set_game_object_id(nil)
	end

	self._units[obj_id] = nil
	self._owners[obj_id] = nil
end

GameNetworkManager.cb_player_profile_created = function (self, obj_id, owner_id)
	local player_game_obj_id = GameSession.game_object_field(self._game, obj_id, "player_game_obj_id")
	local unit = self._units[player_game_obj_id]

	if unit then
		local locomotion_ext = ScriptUnit.extension(unit, "locomotion_system")

		locomotion_ext:setup_player_profile(obj_id)
	end
end

GameNetworkManager.cb_coat_of_arms_created = function (self, obj_id, owner_id)
	local player_manager = Managers.player
	local player_id = GameSession.game_object_field(self._game, obj_id, "player_id")
	local player = player_manager:player(self:temp_player_index(player_id))
	local coat_of_arms = {
		field_color = NetworkLookup.coat_of_arms_field_colors[GameSession.game_object_field(self._game, obj_id, "field_color")],
		division_color = NetworkLookup.coat_of_arms_division_colors[GameSession.game_object_field(self._game, obj_id, "division_color")],
		division_type = NetworkLookup.coat_of_arms_division_types[GameSession.game_object_field(self._game, obj_id, "division_type")],
		variation_1_color = NetworkLookup.coat_of_arms_variation_colors[GameSession.game_object_field(self._game, obj_id, "variation_1_color")],
		variation_2_color = NetworkLookup.coat_of_arms_variation_colors[GameSession.game_object_field(self._game, obj_id, "variation_2_color")],
		variation_1_type = NetworkLookup.coat_of_arms_variation_types[GameSession.game_object_field(self._game, obj_id, "variation_1_type")],
		variation_2_type = NetworkLookup.coat_of_arms_variation_types[GameSession.game_object_field(self._game, obj_id, "variation_2_type")],
		ordinary_color = NetworkLookup.coat_of_arms_ordinary_colors[GameSession.game_object_field(self._game, obj_id, "ordinary_color")],
		ordinary_type = NetworkLookup.coat_of_arms_ordinary_types[GameSession.game_object_field(self._game, obj_id, "ordinary_type")],
		charge_color = NetworkLookup.coat_of_arms_charge_colors[GameSession.game_object_field(self._game, obj_id, "charge_color")],
		charge_type = NetworkLookup.coat_of_arms_charge_types[GameSession.game_object_field(self._game, obj_id, "charge_type")],
		crest = NetworkLookup.coat_of_arms_crests[GameSession.game_object_field(self._game, obj_id, "crest")]
	}

	player:set_coat_of_arms(coat_of_arms)
end

GameNetworkManager.destroy_game_object = function (self, object_id)
	local owner_id = self._owners[object_id]
	local object_destroy_func = NetworkLookup.game_object_functions[GameSession.game_object_field(self._game, object_id, "object_destroy_func")]

	if script_data.network_debug then
		print("DESTROY GAME OBJECT object_id:", object_id, "owner_id:", owner_id, "object_destroy_func:", object_destroy_func, "type:", self._game_object_types[object_id] or "unknown")
	end

	self._game_object_disconnect_callbacks[object_id] = nil

	self[object_destroy_func](self, object_id, owner_id)
	GameSession.destroy_game_object(self._game, object_id)
end

GameNetworkManager.game_object_destroyed = function (self, object_id, owner_id)
	local object_destroy_func = NetworkLookup.game_object_functions[GameSession.game_object_field(self._game, object_id, "object_destroy_func")]

	if script_data.network_debug then
		print("GAME OBJECT DESTROYED object_id:", object_id, "owner_id:", owner_id, "object_destroy_func:", object_destroy_func, "type:", self._game_object_types[object_id] or "unknown")
	end

	self[object_destroy_func](self, object_id, owner_id)
end

GameNetworkManager.migrate_game_object = function (self, object_id, player_id)
	self._migrate_game_object_stack = self._migrate_game_object_stack or {}

	table.insert(self._migrate_game_object_stack, {
		object_id = object_id,
		player_id = player_id
	})
end

GameNetworkManager.game_object_migrated_away = function (self, object_id, new_peer_id)
	local unit = self._units[object_id]

	if Unit.alive(unit) and Unit.has_data(unit, "game_object_migrated_away_cb") then
		Unit.get_data(unit, "game_object_migrated_away_cb")(object_id, new_peer_id)
	end

	self._owners[object_id] = new_peer_id
	self._game_object_disconnect_callbacks[object_id] = nil

	if script_data.migration_debug then
		print("migrated away, object val game_object_created_func: ", GameSession.game_object_field(self._game, object_id, "game_object_created_func"))
		print("migrated away, object val owner_destroy_func: ", GameSession.game_object_field(self._game, object_id, "owner_destroy_func"))
	end
end

GameNetworkManager.game_object_migrated_to_me = function (self, object_id, old_peer_id)
	local unit = self._units[object_id]

	if Unit.alive(unit) and Unit.has_data(unit, "game_object_migrated_to_me_cb") then
		Unit.get_data(unit, "game_object_migrated_to_me_cb")(object_id, old_peer_id)
	end

	self._game_object_disconnect_callbacks[object_id] = Unit.get_data(unit, "game_session_disconnect_callback")
	self._owners[object_id] = Network.peer_id()

	if script_data.migration_debug then
		print("migrated away, object val game_object_created_func: ", GameSession.game_object_field(self._game, object_id, "game_object_created_func"))
		print("migrated away, object val owner_destroy_func: ", GameSession.game_object_field(self._game, object_id, "owner_destroy_func"))
	end
end

GameNetworkManager.game_session_disconnect = function (self, host_id)
	self._game_session_disconnect = true

	for _, callback in pairs(self._game_object_disconnect_callbacks) do
		callback()
	end
end

GameNetworkManager.cb_destroy_gear = function (self, obj_id, owner_id)
	local unit = self._units[obj_id]

	if Managers.lobby.server then
		ScriptUnit.remove_extensions(unit)
	end

	if owner_id ~= Network.peer_id() and not Unit.get_data(unit, "gear_dead") then
		World.destroy_unit(self._world, unit)
	end

	self._units[obj_id] = nil
	self._owners[obj_id] = nil
end

GameNetworkManager.cb_destroy_unit = function (self, obj_id)
	local unit = self._units[obj_id]

	Managers.state.entity:unregister_unit(unit)
	World.destroy_unit(self._world, unit)

	self._units[obj_id] = nil
	self._owners[obj_id] = nil
end

GameNetworkManager.cb_destroy_player_unit = function (self, obj_id)
	local unit = self._units[obj_id]
	local player_manager = Managers.player

	Managers.state.entity:unregister_unit(unit)
	World.destroy_unit(self._world, unit)

	self._units[obj_id] = nil
	self._owners[obj_id] = nil
end

GameNetworkManager.cb_projectile_game_object_destroyed = function (self, obj_id)
	local unit = self._units[obj_id]

	Unit.set_data(unit, "game_object_id", nil)

	self._units[obj_id] = nil
	self._owners[obj_id] = nil
end

GameNetworkManager.cb_do_nothing = function (self)
	return
end

GameNetworkManager.remove = function (self, peer, retain_peer)
	if Managers.admin then
		Managers.admin:unregister_peer(peer)
	end

	if self._object_synchronizing_clients[peer] then
		self._object_synchronizing_clients[peer] = nil
	else
		self:_cleanup_game_objects(peer)
		self:_cleanup_player(peer)
	end

	if not retain_peer then
		GameSession.remove_peer(self._game, peer, self)
	end
end

GameNetworkManager._cleanup_teams = function (self, player)
	local team_manager = Managers.state.team

	if player.team then
		team_manager:remove_player_from_team_by_name(player, player.team.name)
	end
end

GameNetworkManager._cleanup_player = function (self, peer)
	local player_manager = Managers.player
	local player = player_manager:player_from_network_id(peer)

	while player do
		Managers.state.projectile:remove_projectiles(player:player_id())
		self:_cleanup_teams(player)
		player_manager:remove_player(player.index)

		player = player_manager:player_from_network_id(peer)
	end
end

GameNetworkManager._cleanup_game_objects = function (self, peer)
	local objects = GameSession.objects_owned_by(self._game, peer)

	for _, id in ipairs(objects) do
		if self._owners[id] then
			local owner_destroy_func = NetworkLookup.game_object_functions[GameSession.game_object_field(self._game, id, "owner_destroy_func")]

			self[owner_destroy_func](self, id)
		end
	end
end

GameNetworkManager.cb_destroy_object = function (self, object_id)
	return
end

GameNetworkManager.cb_migrate_object = function (self, id)
	return
end

GameNetworkManager.gear_game_object_inventory = function (self, object_id)
	local gear_name = NetworkLookup.inventory_gear[GameSession.game_object_field(self._game, object_id, "gear_name")]
	local user_object_id = GameSession.game_object_field(self._game, object_id, "user_object_id")
	local user_unit = self._units[user_object_id]
	local locomotion = ScriptUnit.extension(user_unit, "locomotion_system")
	local inventory = locomotion:inventory()

	return inventory
end

GameNetworkManager.gear_game_object_owner_locomotion = function (self, object_id)
	if not GameSession.game_object_exists(self._game, object_id) then
		return
	end

	local gear_name = NetworkLookup.inventory_gear[GameSession.game_object_field(self._game, object_id, "gear_name")]
	local user_object_id = GameSession.game_object_field(self._game, object_id, "user_object_id")
	local user_unit = self._units[user_object_id]

	if not user_unit then
		return
	end

	local locomotion = ScriptUnit.extension(user_unit, "locomotion_system")

	return locomotion
end

GameNetworkManager.rpc_stat_weapon_missed = function (self, sender, player_object_id, gear_name_id)
	local player_id = player_object_id
	local player = Managers.player:player(self:temp_player_index(player_id))
	local gear_name = NetworkLookup.gear_names[gear_name_id]

	Managers.state.stats_collector:weapon_missed(player, gear_name)
end

GameNetworkManager.rpc_award_achievement = function (self, sender, player_object_id, achievement_id)
	if not Achievement.unlocked(achievement_id) then
		AchievementHelper:unlock(achievement_id)
		print("GameNetworkManager:rpc_award_achievement", player_object_id, achievement_id)
	end
end

GameNetworkManager.rpc_award_prize = function (self, sender, player_object_id, prize_id)
	print("GameNetworkManager:rpc_award_prize", player_object_id, NetworkLookup.prizes[prize_id])
	Managers.state.event:trigger("awarded_prize", NetworkLookup.prizes[prize_id])
end

GameNetworkManager.rpc_award_medal = function (self, sender, player_object_id, medal_id)
	print("GameNetworkManager:rpc_award_medal", player_object_id, NetworkLookup.medals[medal_id])
	Managers.state.event:trigger("awarded_medal", NetworkLookup.medals[medal_id])
end

GameNetworkManager.rpc_rank_up = function (self, sender, player_object_id, rank)
	print("GameNetworkManager:rpc_rank_up", player_object_id, rank)
	Managers.state.event:trigger("awarded_rank", rank)
end

GameNetworkManager.rpc_gain_xp_and_coins = function (self, sender, reason_id, xp, coins)
	local reason = NetworkLookup.xp_reason[reason_id]

	Managers.state.event:trigger("gained_xp_and_coins", reason, xp, coins)
end

GameNetworkManager.rpc_xp_penalty = function (self, sender, reason_id, amount)
	local reason = NetworkLookup.penalty_reason[reason_id]

	Managers.state.event:trigger("penalty_xp", reason, amount)
end

GameNetworkManager.rpc_destroy_objective = function (self, sender, game_object_id, damage)
	local unit_level_object_id = GameSession.game_object_field(self._game, game_object_id, "unit_game_object_id")
	local level = LevelHelper:current_level(self._world)
	local unit = Level.unit_by_index(level, unit_level_object_id)
	local damage_ext = ScriptUnit.extension(unit, "damage_system")

	damage_ext:die(damage)
end

GameNetworkManager.rpc_raise_parry_block = function (self, sender, user_object_id, slot_name, direction, delay)
	local delay = delay - Network.ping(sender)

	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_raise_parry_block", sender, user_object_id, slot_name, direction, delay)
	end

	local user_unit = self._units[user_object_id]
	local locomotion = ScriptUnit.extension(user_unit, "locomotion_system")

	locomotion:rpc_raise_parry_block(NetworkLookup.inventory_slots[slot_name], NetworkLookup.directions[direction], delay)
end

GameNetworkManager.rpc_lower_parry_block = function (self, sender, user_object_id)
	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_lower_parry_block", sender, user_object_id)
	end

	local user_unit = self._units[user_object_id]
	local locomotion = ScriptUnit.extension(user_unit, "locomotion_system")

	locomotion:rpc_lower_parry_block()
end

GameNetworkManager.rpc_hot_join_synch_parry_block = function (self, sender, player_object_id, slot_name, direction)
	local unit = self._units[player_object_id]
	local locomotion = ScriptUnit.extension(unit, "locomotion_system")

	locomotion:rpc_raise_parry_block(NetworkLookup.inventory_slots[slot_name], NetworkLookup.directions[direction], 0)
end

GameNetworkManager.rpc_raise_shield_block = function (self, sender, user_object_id, slot_name)
	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_raise_shield_block", sender, user_object_id, slot_name)
	end

	local user_unit = self._units[user_object_id]
	local locomotion = ScriptUnit.extension(user_unit, "locomotion_system")

	locomotion:rpc_raise_shield_block(NetworkLookup.inventory_slots[slot_name])
end

GameNetworkManager.rpc_lower_shield_block = function (self, sender, user_object_id)
	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_lower_shield_block", sender, user_object_id)
	end

	local user_unit = self._units[user_object_id]
	local locomotion = ScriptUnit.extension(user_unit, "locomotion_system")

	locomotion:rpc_lower_shield_block()
end

GameNetworkManager.rpc_hot_join_synch_shield_block = function (self, sender, player_object_id, slot_name)
	local unit = self._units[player_object_id]
	local locomotion = ScriptUnit.extension(unit, "locomotion_system")

	locomotion:rpc_raise_shield_block(NetworkLookup.inventory_slots[slot_name])
end

GameNetworkManager.rpc_pose_melee_weapon = function (self, sender, user_object_id, direction)
	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_pose_melee_weapon", sender, user_object_id, direction)
	end

	local user_unit = self._units[user_object_id]
	local locomotion = ScriptUnit.extension(user_unit, "locomotion_system")

	locomotion:rpc_pose_melee_weapon(NetworkLookup.directions[direction])
end

GameNetworkManager.rpc_stop_posing_melee_weapon = function (self, sender, user_object_id)
	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_stop_posing_melee_weapon", sender, user_object_id)
	end

	local user_unit = self._units[user_object_id]

	if user_unit then
		local locomotion = ScriptUnit.extension(user_unit, "locomotion_system")

		locomotion:rpc_stop_posing_melee_weapon()
	end
end

GameNetworkManager.rpc_hot_join_synch_pose = function (self, sender, user_object_id, direction)
	local unit = self._units[user_object_id]
	local locomotion = ScriptUnit.extension(unit, "locomotion_system")

	locomotion:rpc_hot_join_synch_pose(NetworkLookup.inventory_slots[direction])
end

GameNetworkManager.rpc_synch_ready_projectile = function (self, sender, game_object_id, slot_name, projectile_name)
	local unit = self._units[game_object_id]
	local locomotion = ScriptUnit.extension(unit, "locomotion_system")
	local inventory = locomotion:inventory()
	local gear = inventory:_gear(NetworkLookup.inventory_slots[slot_name])
	local extensions = gear:extensions()
	local weapon_ext = extensions.base

	weapon_ext:ready_projectile(NetworkLookup.inventory_slots[slot_name])
end

GameNetworkManager.rpc_gear_destroyed = function (self, sender, object_id)
	if script_data.network_debug then
		print("GameNetworkManager:rpc_gear_dead")
	end

	local locomotion = self:gear_game_object_owner_locomotion(object_id)

	if not locomotion then
		return
	end

	local unit = self._units[object_id]

	locomotion:rpc_gear_dead(unit)
end

GameNetworkManager.rpc_gear_dead = function (self, sender, object_id)
	if script_data.network_debug then
		print("GameNetworkManager:rpc_gear_dead")
	end

	local locomotion = self:gear_game_object_owner_locomotion(object_id)

	if not locomotion then
		return
	end

	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_gear_dead", sender, object_id)
	end

	local unit = self._units[object_id]

	locomotion:rpc_gear_dead(unit)
	Unit.set_data(unit, "gear_dead", true)
end

GameNetworkManager.rpc_player_dead = function (self, sender, object_id, is_instakill, damage_type_id, hit_zone_id, direction)
	local unit = self._units[object_id]
	local locomotion = ScriptUnit.extension(unit, "locomotion_system")
	local damage_ext = ScriptUnit.extension(unit, "damage_system")
	local hit_zone = NetworkLookup.hit_zones[hit_zone_id]
	local damage_type = NetworkLookup.damage_types[damage_type_id]

	locomotion:player_dead(is_instakill, damage_type, hit_zone, direction)
	damage_ext:player_dead()
end

GameNetworkManager.rpc_player_knocked_down = function (self, sender, object_id, hit_zone_id, impact_direction, damage_type)
	local unit = self._units[object_id]
	local locomotion = ScriptUnit.extension(unit, "locomotion_system")
	local damage_ext = ScriptUnit.extension(unit, "damage_system")

	locomotion:player_knocked_down(NetworkLookup.hit_zones[hit_zone_id], impact_direction, NetworkLookup.damage_types[damage_type])
	damage_ext:player_knocked_down()
end

GameNetworkManager.rpc_suicide = function (self, sender, object_id)
	local unit = self._units[object_id]
	local damage_ext = ScriptUnit.extension(unit, "damage_system")

	damage_ext:die(Managers.player:owner(unit))
end

GameNetworkManager.rpc_self_knock_down = function (self, sender, object_id)
	local unit = self._units[object_id]
	local damage_ext = ScriptUnit.extension(unit, "damage_system")

	damage_ext:self_knock_down()
end

GameNetworkManager.rpc_player_deserting = function (self, sender, player_id, deserting, deserter_timer)
	local player_manager = Managers.player
	local player = player_manager:player(self:temp_player_index(player_id))

	if deserting then
		Managers.state.event:trigger("event_deserting_activated", player, deserter_timer)
	else
		Managers.state.event:trigger("event_deserting_deactivated", player)
	end
end

GameNetworkManager.rpc_show_ranged_damage_number = function (self, sender, player_id, damage_type_id, damage, position, damage_range_type_id, impact_direction, armour_type_id)
	local player_manager = Managers.player
	local player = player_manager:player(self:temp_player_index(player_id))
	local damage_type = NetworkLookup.damage_types[damage_type_id]
	local damage_range_type = NetworkLookup.damage_range_types[damage_range_type_id]
	local armour_type = NetworkLookup.armour_types[armour_type_id]

	Managers.state.event:trigger("show_damage_number", player, damage_type, damage, position, damage_range_type, impact_direction, armour_type)
end

GameNetworkManager.rpc_horse_dead = function (self, sender, mount_object_id, impact_direction)
	local mount = self._units[mount_object_id]
	local horse_locomotion = ScriptUnit.extension(mount, "locomotion_system")
	local horse_damage = ScriptUnit.extension(mount, "damage_system")

	horse_locomotion:rpc_set_dead(impact_direction)
	horse_damage:rpc_set_dead()
end

GameNetworkManager.rpc_try_kill_owned_horse = function (self, sender, mount_object_id)
	local mount = self._units[mount_object_id]

	if Unit.alive(mount) then
		local damage_ext = ScriptUnit.extension(mount, "damage_system")

		if not damage_ext:is_dead() then
			damage_ext:die()
		end
	end
end

GameNetworkManager.rpc_notify_lobby_joined = function (self, sender)
	local is_dedicated = script_data.settings.dedicated_server

	if is_dedicated and Managers.admin:is_player_banned(sender) then
		RPC.rpc_denied_to_enter_game(sender, "banned")
	elseif is_dedicated and Managers.admin:is_server_locked() then
		RPC.rpc_denied_to_enter_game(sender, "locked")
	elseif is_dedicated and not Managers.admin:check_reserved_slots(sender) then
		RPC.rpc_denied_to_enter_game(sender, "reserved_slot")
	else
		local level_key = Managers.lobby:get_lobby_data("level_key")
		local game_mode_key = Managers.lobby:get_lobby_data("game_mode_key")
		local win_score = Managers.lobby:get_lobby_data("win_score")
		local time_limit = Managers.lobby:get_lobby_data("time_limit")

		RPC.rpc_load_level(sender, NetworkLookup.level_keys[level_key], NetworkLookup.game_mode_keys[game_mode_key], self._state:game_start_countdown(), win_score, time_limit)
		RPC.rpc_permission_to_enter_game(sender)
	end
end

GameNetworkManager.rpc_drop_in = function (self, sender, local_id, backend_profile_id, is_demo, anti_cheat_key)
	if self._game then
		GameSession.add_peer(self._game, sender)

		self._object_synchronizing_clients[sender] = {
			local_id = local_id,
			backend_profile_id = backend_profile_id,
			is_demo = is_demo,
			anti_cheat_key = anti_cheat_key
		}
	end
end

GameNetworkManager.game_object_sync_done = function (self, remote_id)
	if Managers.lobby.server then
		local player_manager = Managers.player
		local anti_cheat_key = self._object_synchronizing_clients[remote_id].anti_cheat_key
		local is_demo = self._object_synchronizing_clients[remote_id].is_demo
		local backend_profile_id = self._object_synchronizing_clients[remote_id].backend_profile_id
		local local_id = self._object_synchronizing_clients[remote_id].local_id

		self._object_synchronizing_clients[remote_id] = nil

		local player = player_manager:add_remote_player(local_id, nil, remote_id, backend_profile_id, is_demo)

		self:_hot_join_synch(remote_id, player)

		local squad_screen, auto_team = Managers.state.game_mode:squad_screen_spawning()
		local skip_team_selection = false

		if not squad_screen then
			Managers.state.team:add_player_to_team_by_side(player, auto_team)
		elseif player.team.name ~= "unassigned" then
			skip_team_selection = true
		end

		if Managers.admin then
			Managers.admin:register_peer(remote_id, anti_cheat_key)
		end

		RPC.rpc_game_started(remote_id, skip_team_selection)
	end
end

GameNetworkManager._hot_join_synch = function (self, sender, player)
	Managers.state.team:hot_join_synch(sender, player)
	Managers.state.entity_system:hot_join_synch(sender, player)
	Managers.state.spawn:hot_join_synch(sender, player)
	Managers.state.game_mode:hot_join_synch(sender, player)

	if script_data.unlimited_ammo then
		RPC.rpc_toggle_unlimited_ammo(sender, true)
	end

	RPC.rpc_synch_round_time(sender, Managers.time:time("round"), Managers.time:active("round"))
end

GameNetworkManager.rpc_synch_player_anim_state = function (self, sender, game_object_id, ...)
	local unit = self._units[game_object_id]

	Unit.animation_set_state(unit, ...)
end

GameNetworkManager.rpc_synch_horse_anim_state = function (self, sender, game_object_id, ...)
	local unit = self._units[game_object_id]

	Unit.animation_set_state(unit, ...)
end

GameNetworkManager.rpc_synch_round_time = function (self, sender, round_time, active)
	round_time = round_time + Network.ping(sender) / 2

	if not Managers.time:has_timer("round") then
		Managers.time:register_timer("round", "main", round_time)
	else
		Managers.time:set_time("round", round_time)
	end

	Managers.time:set_active("round", active)
end

GameNetworkManager.rpc_synch_game_mode_time_limit = function (self, sender, time_limit)
	Managers.state.game_mode:set_time_limit(time_limit)
end

GameNetworkManager.rpc_add_player_to_team = function (self, sender, player_game_object_id, team_name_id)
	local player_manager = Managers.player
	local team_manager = Managers.state.team

	if script_data.network_debug then
		print("rpc_add_player_to_team() player_game_object_id:", player_game_object_id)
	end

	if not GameSession.game_object_exists(self._game, player_game_object_id) then
		Application.warning("rpc_add_player_to_team - Game object doesn't exist", player_game_object_id)

		return
	end

	local player_id = self:temp_player_index(player_game_object_id)
	local player = player_manager:player(player_id)
	local team_name = NetworkLookup.team[team_name_id]

	team_manager:add_player_to_team_by_name(player, team_name)
end

GameNetworkManager.rpc_remove_player_from_team = function (self, sender, player_game_object_id, team_name_id)
	local player_manager = Managers.player
	local team_manager = Managers.state.team

	if script_data.network_debug then
		print("rpc_remove_player_from_team() player_game_object_id:", player_game_object_id)
	end

	local player_id = self:temp_player_index(player_game_object_id)
	local player = player_manager:player(player_id)
	local team_name = NetworkLookup.team[team_name_id]

	team_manager:remove_player_from_team_by_name(player, team_name)
end

GameNetworkManager.rpc_move_player_to_team = function (self, sender, player_game_object_id, team_name_id)
	local player_manager = Managers.player
	local team_manager = Managers.state.team

	if script_data.network_debug then
		print("rpc_add_player_to_team() player_game_object_id:", player_game_object_id)
	end

	local player_id = self:temp_player_index(player_game_object_id)
	local player = player_manager:player(player_id)
	local team_name = NetworkLookup.team[team_name_id]

	team_manager:move_player_to_team_by_name(player, team_name)
end

GameNetworkManager.rpc_request_to_join_squad = function (self, sender, player_game_object_id, squad_id)
	local player_manager = Managers.player
	local player_id = self:temp_player_index(player_game_object_id)
	local player = player_manager:player(player_id)
	local squad = player.team.squads[squad_id]
	local old_squad = player.team.squads[player.squad_index]

	if squad:can_join(player) and (old_squad == nil or old_squad:can_leave(player)) then
		if old_squad then
			old_squad:remove_member(player)
		end

		squad:add_member(player)
	end
end

GameNetworkManager.rpc_request_to_leave_squad = function (self, send, player_game_object_id, squad_id)
	local player_manager = Managers.player
	local player_id = self:temp_player_index(player_game_object_id)
	local player = player_manager:player(player_id)
	local squad = player.team.squads[squad_id]

	if squad:can_leave(player) then
		squad:remove_member(player)
	end
end

GameNetworkManager.rpc_set_squad_corporal = function (self, sender, player_game_object_id, squad_id)
	local player_manager = Managers.player
	local player_id = self:temp_player_index(player_game_object_id)
	local player = player_manager:player(player_id)

	player.team.squads[squad_id]:set_corporal(player)
end

GameNetworkManager.rpc_add_player_to_squad = function (self, sender, player_game_object_id, squad_id)
	local player_manager = Managers.player
	local player_id = self:temp_player_index(player_game_object_id)
	local player = player_manager:player(player_id)

	player.team.squads[squad_id]:add_member(player)
end

GameNetworkManager.rpc_remove_player_from_squad = function (self, sender, player_game_object_id, squad_id)
	local player_manager = Managers.player
	local player_id = self:temp_player_index(player_game_object_id)
	local player = player_manager:player(player_id)

	player.team.squads[squad_id]:remove_member(player)
end

GameNetworkManager.rpc_set_max_squad_size = function (self, sender, max_squad_size)
	Managers.state.team:team_by_name("red"):set_max_squad_size(max_squad_size)
	Managers.state.team:team_by_name("white"):set_max_squad_size(max_squad_size)
end

GameNetworkManager.rpc_game_started = function (self, sender, skip_team_selection)
	self._game_started = true

	Managers.state.event:trigger("game_started", skip_team_selection)
end

GameNetworkManager.rpc_request_to_tag_player_unit = function (self, sender, player_game_object_id, tagged_player_unit_game_object_id)
	local player_manager = Managers.player
	local player_id = self:temp_player_index(player_game_object_id)
	local player = player_manager:player(player_id)
	local tagged_unit = self._units[tagged_player_unit_game_object_id]
	local tagging_manager = Managers.state.tagging

	if tagging_manager:can_tag_player_unit(player, tagged_unit) then
		local locomotion = ScriptUnit.extension(player.player_unit, "locomotion_system")
		local tagging_duration_multiplier = locomotion:has_perk("spotter") and Perks.spotter.tagging_duration_multiplier or 1

		tagging_manager:add_player_unit_tag(player, tagged_unit, Managers.time:time("round") + PlayerActionSettings.tagging.duration * tagging_duration_multiplier)
	end
end

GameNetworkManager.rpc_request_to_tag_objective = function (self, sender, player_game_object_id, tagged_objective_unit_level_index)
	local player_manager = Managers.player
	local player_id = self:temp_player_index(player_game_object_id)
	local player = player_manager:player(player_id)
	local level = LevelHelper:current_level(self._world)
	local tagged_unit = Level.unit_by_index(level, tagged_objective_unit_level_index)
	local tagging_manager = Managers.state.tagging

	if tagging_manager:can_tag_objective(player, tagged_unit) then
		local locomotion = ScriptUnit.extension(player.player_unit, "locomotion_system")
		local tagging_duration_multiplier = locomotion:has_perk("spotter") and Perks.spotter.tagging_duration_multiplier or 1

		tagging_manager:add_objective_tag(player, tagged_unit, Managers.time:time("round") + PlayerActionSettings.tagging.duration * tagging_duration_multiplier)
	end
end

GameNetworkManager.rpc_request_knocked_down_help = function (self, sender, tagger_unit_id, tagged_unit_id)
	local tagger_unit = self._units[tagger_unit_id]
	local tagged_unit = self._units[tagged_unit_id]
	local player = Managers.player:owner(tagged_unit)

	if Managers.lobby.server then
		local player_network_id = player:network_id()

		if Managers.state.tagging:can_tag_player_unit(player, tagged_unit) then
			RPC.rpc_knocked_down_help(player_network_id, tagger_unit_id)
		end
	end
end

GameNetworkManager.rpc_knocked_down_help = function (self, sender, tagger_unit_id)
	local tagger_unit = self._units[tagger_unit_id]

	Managers.state.event:trigger("recieved_help_request", tagger_unit)
end

GameNetworkManager.rpc_request_squad_knocked_down_help = function (self, sender, tagger_unit_id)
	local tagger_unit = self._units[tagger_unit_id]
	local player = Managers.player:owner(tagger_unit)
	local squad = player.team.squads[player.squad_index]

	if squad then
		local squad_members = squad:members()

		for squad_member, _ in pairs(squad_members) do
			if player ~= squad_member then
				local player_network_id = squad_member:network_id()

				RPC.rpc_knocked_down_help(player_network_id, tagger_unit_id)
			end
		end
	end
end

GameNetworkManager.rpc_play_particle_effect = function (self, sender, effect_id, game_object_id, node_id, offset, rotation_offset, linked)
	if Managers.lobby.server then
		self:send_rpc_clients("rpc_play_particle_effect", effect_id, game_object_id, node_id, offset, rotation_offset, linked)
	end

	Managers.state.event:trigger("event_play_particle_effect", NetworkLookup.effects[effect_id], self._units[game_object_id], node_id, offset, rotation_offset, linked)
end

GameNetworkManager.rpc_output_debug_console_text = function (self, sender, text_id, color, display_time)
	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_output_debug_console_text", sender, text_id, color, display_time)
	end

	Managers.state.hud:output_console_text(L(NetworkLookup.localized_strings[text_id]), color, display_time)
end

GameNetworkManager.rpc_output_debug_screen_text = function (self, sender, text_id, text_size, time, color)
	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_output_debug_screen_text", sender, text_id, text_size, time, color)
	end

	if time == -1 then
		time = nil
	end

	if text_size == -1 then
		text_size = nil
	end

	Managers.state.debug_text:output_screen_text(L(NetworkLookup.localized_strings[text_id]), text_size, time, color)
end

GameNetworkManager.rpc_output_debug_unit_text = function (self, sender, text_id, text_size, unit_game_object_id, node_index, offset, time, color)
	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_output_debug_unit_text", sender, text_id, text_size, unit_game_object_id, node_index, offset, time, color)
	end

	local unit = self._units[unit_game_object_id]

	assert(unit, "[GameNetworkManager] Game object ID not found in table self._units")

	if time == -1 then
		time = nil
	end

	if text_size == -1 then
		text_size = nil
	end

	Managers.state.debug_text:clear_unit_text(unit, nil)
	Managers.state.debug_text:output_unit_text(L(NetworkLookup.localized_strings[text_id]), text_size, unit, node_index, offset, time, nil, color)
end

GameNetworkManager.rpc_output_debug_lvl_unit_text = function (self, sender, text_id, text_size, unit_index, node_index, offset, time, color)
	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_output_debug_lvl_unit_text", sender, text_id, text_size, unit_index, node_index, offset, time, color)
	end

	local level = LevelHelper:current_level(self._world)
	local unit = Level.unit_by_index(level, unit_index)

	assert(unit, "[GameNetworkManager] Unit must be spawned statically in level")

	if time == -1 then
		time = nil
	end

	if text_size == -1 then
		text_size = nil
	end

	Managers.state.debug_text:clear_unit_text(unit, nil)
	Managers.state.debug_text:output_unit_text(L(NetworkLookup.localized_strings[text_id]), text_size, unit, node_index, offset, time, nil, color)
end

GameNetworkManager.rpc_output_debug_world_text = function (self, sender, id, text_id, text_size, position, time, color)
	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_output_debug_world_text", sender, id, text_id, text_size, position, time, color)
	end

	if time == -1 then
		time = nil
	end

	if text_size == -1 then
		text_size = nil
	end

	Managers.state.debug_text:clear_world_text(id)
	Managers.state.debug_text:output_world_text(L(NetworkLookup.localized_strings[text_id]), text_size, position, time, id, color)
end

GameNetworkManager.rpc_anim_event = function (self, sender, anim_id, object_id)
	local unit = self._units[object_id]

	if not unit or not Unit.alive(unit) then
		return
	end

	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_anim_event", sender, anim_id, object_id)
	end

	local event = NetworkLookup.anims[anim_id]

	assert(event, "[GameNetworkManager] Lookup missing for event_id", anim_id)
	ScriptUnit.extension(unit, "locomotion_system"):rpc_animation_event(event)
end

GameNetworkManager.rpc_anim_event_variable_float = function (self, sender, anim_id, object_id, variable_id, variable_value)
	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_anim_event_variable_float", sender, anim_id, object_id, variable_id, variable_value)
	end

	local event = NetworkLookup.anims[anim_id]

	assert(event, "[GameNetworkManager] Lookup missing for event_id", anim_id)

	local unit = self._units[object_id]
	local locomotion = ScriptUnit.extension(unit, "locomotion_system")
	local variable_name = NetworkLookup.anims[variable_id]
	local variable_index = Unit.animation_find_variable(unit, variable_name)

	locomotion:rpc_animation_set_variable(variable_index, variable_value)
	locomotion:rpc_animation_event(event)
end

GameNetworkManager.rpc_bow_draw_animation_event = function (self, sender, anim_id, object_id, draw_time_id, draw_time, tense_time_id, tense_time, hold_time_id, hold_time)
	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_bow_draw_animation_event", sender, anim_id, object_id, draw_time_id, draw_time, tense_time_id, tense_time, hold_time_id, hold_time)
	end

	local event = NetworkLookup.anims[anim_id]

	assert(event, "[GameNetworkManager] Lookup missing for event_id", anim_id)

	local unit = self._units[object_id]
	local locomotion = ScriptUnit.extension(unit, "locomotion_system")
	local variable_name = NetworkLookup.anims[draw_time_id]
	local variable_index = Unit.animation_find_variable(unit, variable_name)

	locomotion:rpc_animation_set_variable(variable_index, draw_time)

	variable_name = NetworkLookup.anims[tense_time_id]
	variable_index = Unit.animation_find_variable(unit, variable_name)

	locomotion:rpc_animation_set_variable(variable_index, tense_time)

	variable_name = NetworkLookup.anims[hold_time_id]
	variable_index = Unit.animation_find_variable(unit, variable_name)

	locomotion:rpc_animation_set_variable(variable_index, hold_time)
	locomotion:rpc_animation_event(event)
end

GameNetworkManager.rpc_request_mount = function (self, sender, rider_object_id, mount_object_id, player_id)
	local unit = self._units[mount_object_id]
	local player_manager = Managers.player
	local mount_owner = player_manager:owner(unit)

	assert(not mount_owner or mount_owner.temp_random_user_id ~= player_id, "Requesting ownership of already owned mount.")

	if mount_owner or not Unit.alive(unit) or ScriptUnit.extension(unit, "damage_system"):is_dead() then
		RPC.rpc_mount_denied(sender, rider_object_id, mount_object_id)
	else
		self:send_rpc_clients_except("rpc_mounted_husk", sender, rider_object_id, mount_object_id, player_id)

		if sender ~= Network.peer_id() then
			self:rpc_mounted_husk(Network.peer_id(), rider_object_id, mount_object_id, player_id)
		end

		if self._owners[mount_object_id] ~= sender then
			GameSession.migrate_game_object(self._game, mount_object_id, sender, self)
			RPC.rpc_mount_confirmed(sender, rider_object_id, mount_object_id)

			self._owners[mount_object_id] = sender
		elseif sender == Network.peer_id() then
			self:rpc_mount_confirmed(sender, rider_object_id, mount_object_id)
		else
			RPC.rpc_mount_confirmed(sender, rider_object_id, mount_object_id)
		end
	end
end

GameNetworkManager.rpc_kicked = function (self, sender, msg)
	Managers.state.event:trigger("kicked_from_game", msg)
	self:leave_game()
end

GameNetworkManager.rpc_unmount = function (self, sender, rider_object_id, mount_object_id)
	local rider = self._units[rider_object_id]
	local mount = self._units[mount_object_id]

	Unit.set_data(mount, "user_unit", nil)
	ScriptUnit.extension(rider, "locomotion_system"):rpc_unmount(mount)
end

GameNetworkManager.rpc_unmounted_husk = function (self, sender, rider_object_id, mount_object_id)
	local rider = self._units[rider_object_id]
	local mount = self._units[mount_object_id]

	Unit.set_data(mount, "user_unit", nil)
	Managers.player:relinquish_unit_ownership(mount)

	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_unmounted_husk", sender, rider_object_id, mount_object_id)
	end

	ScriptUnit.extension(rider, "locomotion_system"):set_mounted()
end

GameNetworkManager.rpc_mounted_husk = function (self, sender, rider_object_id, mount_object_id, player_id)
	local rider = self._units[rider_object_id]
	local mount = self._units[mount_object_id]

	Unit.set_data(mount, "user_unit", rider)
	Managers.player:assign_unit_ownership(mount, player_id)
	ScriptUnit.extension(rider, "locomotion_system"):set_mounted(mount)
end

GameNetworkManager.rpc_mount_confirmed = function (self, sender, rider_object_id, mount_object_id)
	local rider = self._units[rider_object_id]
	local mount = self._units[mount_object_id]

	if not Unit.alive(mount) then
		return
	end

	Unit.set_data(mount, "user_unit", rider)
	Managers.player:assign_unit_ownership(mount, Unit.get_data(rider, "owner_player_index"))
end

GameNetworkManager.rpc_mount_denied = function (self, sender, rider_object_id, mount_object_id)
	local rider = self._units[rider_object_id]
	local mount = self._units[mount_object_id]

	if Unit.alive(rider) then
		local locomotion_ext = ScriptUnit.extension(rider, "locomotion_system")

		locomotion_ext:rpc_mount_denied(mount_object_id, Unit.alive(mount) and mount)
	end
end

GameNetworkManager.rpc_fire_weapon = function (self, sender, shooter_game_object_id)
	local unit = self._units[shooter_game_object_id]
	local locomotion = ScriptUnit.extension(unit, "locomotion_system")
	local inventory = locomotion:inventory()

	inventory:network_recieve_fire()
end

GameNetworkManager.rpc_fire_weapon_at_position = function (self, sender, shooter_game_object_id, position, normal)
	local unit = self._units[shooter_game_object_id]
	local locomotion = ScriptUnit.extension(unit, "locomotion_system")
	local inventory = locomotion:inventory()

	inventory:network_recieve_fire(position, normal)
end

GameNetworkManager.rpc_ready_projectile = function (self, sender, game_object_id, slot_name, projectile_name)
	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_ready_projectile", sender, game_object_id, slot_name, projectile_name)
	end

	local unit = self._units[game_object_id]
	local locomotion = ScriptUnit.extension(unit, "locomotion_system")
	local inventory = locomotion:inventory()
	local gear = inventory:_gear(NetworkLookup.inventory_slots[slot_name])
	local extensions = gear:extensions()
	local weapon_ext = extensions.base

	weapon_ext:ready_projectile(NetworkLookup.inventory_slots[slot_name])
end

GameNetworkManager.rpc_release_projectile = function (self, sender, game_object_id, slot_name)
	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_release_projectile", sender, game_object_id, slot_name)
	end

	local unit = self._units[game_object_id]
	local locomotion = ScriptUnit.extension(unit, "locomotion_system")
	local inventory = locomotion:inventory()
	local gear = inventory:_gear(NetworkLookup.inventory_slots[slot_name])
	local extensions = gear:extensions()
	local weapon_ext = extensions.base

	weapon_ext:release_projectile(NetworkLookup.inventory_slots[slot_name])
end

GameNetworkManager.rpc_spawn_projectile = function (self, sender, player_index, user_obj_id, weapon_object_id, projectile_name_id, gear_name_id, position, exit_velocity, gravity_multiplier, damage_multiplier, properties_id)
	local user_unit = self._units[user_obj_id]
	local weapon_unit = self._units[weapon_object_id]

	if not user_unit or not weapon_unit then
		return
	end

	local game = self._game

	if script_data.projectile_debug then
		local drawer = Managers.state.debug:drawer({
			mode = "retained",
			name = "script_data.projectile_debug"
		})

		drawer:sphere(position, 0.05, Color(0, 255, 0))
	end

	Managers.state.projectile:spawn_projectile(player_index, user_unit, weapon_unit, projectile_name_id, gear_name_id, position, exit_velocity, gravity_multiplier, damage_multiplier, properties_id)
end

GameNetworkManager.create_projectile_game_object = function (self, player_index, user_unit, weapon_unit, projectile_name_id, gear_name_id, position, exit_velocity, gravity_multiplier, damage_multiplier, properties_id, projectile_unit_name, unit)
	local data_table = {
		husk_unit = NetworkLookup.husks[projectile_unit_name],
		position = position,
		projectile_name_id = projectile_name_id,
		gear_name_id = gear_name_id,
		exit_velocity = exit_velocity,
		user_object_id = self:game_object_id(user_unit),
		weapon_object_id = self:game_object_id(weapon_unit),
		gravity_multiplier = gravity_multiplier,
		damage_multiplier = damage_multiplier,
		properties_id = properties_id,
		player_index = player_index,
		game_object_created_func = NetworkLookup.game_object_functions.cb_spawn_projectile,
		owner_destroy_func = NetworkLookup.game_object_functions.cb_do_nothing,
		object_destroy_func = NetworkLookup.game_object_functions.cb_projectile_game_object_destroyed
	}
	local callback = callback(self, "cb_projectile_game_session_disconnect", unit)
	local obj_id = self:create_game_object("projectile_unit", data_table, callback)

	self._units[obj_id] = unit
	self._owners[obj_id] = Network.peer_id()

	Unit.set_data(unit, "game_object_id", obj_id)
	Unit.set_data(unit, "user_unit", user_unit)
end

GameNetworkManager.temp_player_index = function (self, player_id)
	local player_manager = Managers.player
	local players = player_manager:players()
	local max_players = player_manager.MAX_PLAYERS

	for player_index = 1, max_players do
		if player_manager:player_exists(player_index) then
			local player = player_manager:player(player_index)

			if player.temp_random_user_id == player_id then
				return player_index
			end
		end
	end

	if player_manager:player_exists("York") then
		local player = player_manager:player("York")

		if player.temp_random_user_id == player_id then
			return "York"
		end
	end

	if player_manager:player_exists("Lancaster") then
		local player = player_manager:player("Lancaster")

		if player.temp_random_user_id == player_id then
			return "Lancaster"
		end
	end

	for player_index, player in pairs(players) do
		if player.temp_random_user_id == player_id then
			return player_index
		end
	end

	return player_id
end

GameNetworkManager.cb_projectile_game_session_disconnect = function (self, projectile_unit)
	Managers.state.entity:unregister_unit(projectile_unit)
	World.destroy_unit(self._world, projectile_unit)
end

GameNetworkManager.rpc_set_gear_wielded = function (self, sender, game_object_id, slot_name, wielded, ignore_sound)
	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_set_gear_wielded", sender, game_object_id, slot_name, wielded, ignore_sound)
	end

	local unit = self._units[game_object_id]
	local locomotion = ScriptUnit.extension(unit, "locomotion_system")
	local inventory = locomotion:inventory()

	inventory:set_gear_wielded(NetworkLookup.inventory_slots[slot_name], wielded, ignore_sound)
end

GameNetworkManager.rpc_set_visor_open = function (self, sender, game_object_id, open, fast)
	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_set_visor_open", sender, game_object_id, open, fast)
	end

	local unit = self._units[game_object_id]
	local locomotion = ScriptUnit.extension(unit, "locomotion_system")
	local inventory = locomotion:inventory()

	inventory:set_visor_open(open, fast)
end

GameNetworkManager.rpc_add_damage = function (self, sender, attacker_player_id, attacker_game_object_id, victim_game_object_id, damage_type, damage, position, normal, damage_range_type, gear_name_id, hit_zone_id, impact_direction, real_damage, range)
	local victim_unit = self._units[victim_game_object_id]

	if not victim_unit or not Unit.alive(victim_unit) then
		return
	end

	if ScriptUnit.has_extension(victim_unit, "damage_system") then
		self:_apply_damage(attacker_player_id, attacker_game_object_id, victim_unit, damage_type, damage, position, normal, damage_range_type, gear_name_id, hit_zone_id, impact_direction, real_damage, range)
	end
end

GameNetworkManager.rpc_add_generic_damage = function (self, sender, attacker_player_id, attacker_game_object_id, victim_level_object_id, damage_type, damage, position, normal, damage_range_type, gear_name_id, hit_zone_id, impact_direction)
	local level = LevelHelper:current_level(self._world)
	local victim_unit = Level.unit_by_index(level, victim_level_object_id)

	if not victim_unit or not Unit.alive(victim_unit) then
		return
	end

	if ScriptUnit.has_extension(victim_unit, "damage_system") then
		self:_apply_damage(attacker_player_id, attacker_game_object_id, victim_unit, damage_type, damage, position, normal, damage_range_type, gear_name_id, hit_zone_id, impact_direction)
	end
end

GameNetworkManager.rpc_add_damage_over_time = function (self, sender, attacker_player_id, victim_game_object_id, damage_type)
	local victim_unit = self._units[victim_game_object_id]

	if not victim_unit or not Unit.alive(victim_unit) then
		return
	end

	if ScriptUnit.has_extension(victim_unit, "damage_system") then
		local attacker = Managers.player:player(self:temp_player_index(attacker_player_id))
		local damage_extension = ScriptUnit.extension(victim_unit, "damage_system")

		damage_extension:network_recieve_add_damage_over_time(attacker, NetworkLookup.damage_over_time_types[damage_type])
	end
end

GameNetworkManager._apply_damage = function (self, attacker_player_id, attacker_game_object_id, victim_unit, damage_type, damage, position, normal, damage_range_type, gear_name_id, hit_zone_id, impact_direction, real_damage, range)
	local attacker = Managers.player:player(self:temp_player_index(attacker_player_id))
	local attacker_unit = self._units[attacker_game_object_id]
	local damage_range_type = NetworkLookup.damage_range_types[damage_range_type]
	local friendly_fire_multiplier = Managers.state.team:friendly_fire_multiplier(attacker_unit, victim_unit, damage_range_type)
	local damage = friendly_fire_multiplier * damage
	local mirrored = false
	local damage_extension = ScriptUnit.extension(victim_unit, "damage_system")
	local is_on_same_team = Managers.state.team:is_on_same_team(attacker_unit, victim_unit)
	local mirror_damage = AttackDamageRangeTypes[damage_range_type].mirrored
	local is_alive = damage_extension:is_alive()

	if is_on_same_team and mirror_damage and is_alive then
		mirrored = true
		attacker_unit, victim_unit = victim_unit, attacker_unit
		damage_extension = ScriptUnit.extension(victim_unit, "damage_system")
	end

	damage_extension:network_recieve_add_damage(attacker, Unit.alive(attacker_unit) and attacker_unit, NetworkLookup.damage_types[damage_type], damage, position, normal, damage_range_type, NetworkLookup.gear_names[gear_name_id], NetworkLookup.hit_zones[hit_zone_id], impact_direction, real_damage or damage, range, mirrored)
end

GameNetworkManager.rpc_trigger_request = function (self, sender, player_unit_id, interactable_unit_id)
	local player_unit = self._units[player_unit_id]
	local player = Managers.player:owner(player_unit)
	local side = player.team.side
	local current_level = LevelHelper:current_level(self._world)
	local interactable_unit = Level.unit_by_index(current_level, interactable_unit_id)
	local extension = ScriptUnit.extension(interactable_unit, "objective_system")

	if extension:active(side) and not extension:interactor() and extension:can_interact(player) then
		InteractionHelper:confirm_request("trigger", sender, player_unit_id)
		extension:set_interactor(player_unit_id)
		Unit.flow_event(interactable_unit, "lua_assault_interact_announcement")
	else
		InteractionHelper:deny_request("trigger", sender, player_unit_id)
	end
end

GameNetworkManager.rpc_trigger_confirmed = function (self, sender, player_unit_id)
	local player_unit = self._units[player_unit_id]
	local extension = ScriptUnit.extension(player_unit, "locomotion_system")

	InteractionHelper:confirmed("trigger", extension)
end

GameNetworkManager.rpc_trigger_denied = function (self, sender, player_unit_id)
	local player_unit = self._units[player_unit_id]
	local extension = ScriptUnit.extension(player_unit, "locomotion_system")

	InteractionHelper:denied("trigger", extension)
end

GameNetworkManager.rpc_trigger_abort = function (self, sender, player_unit_id, interactable_unit_id)
	local current_level = LevelHelper:current_level(self._world)
	local interactable_unit = Level.unit_by_index(current_level, interactable_unit_id)
	local extension = ScriptUnit.extension(interactable_unit, "objective_system")

	if extension:interactor() == player_unit_id then
		extension:set_interactor(nil)
	end
end

GameNetworkManager.rpc_trigger_complete = function (self, sender, player_unit_id, interactable_unit_id)
	local player_unit = self._units[player_unit_id]
	local current_level = LevelHelper:current_level(self._world)
	local interactable_unit = Level.unit_by_index(current_level, interactable_unit_id)
	local player = Managers.player:owner(player_unit)
	local interactable_name = Unit.get_data(interactable_unit, "interact_settings", "name")
	local event_name = player.team.side .. "_" .. interactable_name .. "_triggered"
	local extension = ScriptUnit.extension(interactable_unit, "objective_system")

	if extension:interactor() ~= player_unit_id then
		return
	end

	extension:interaction_complete(player)

	if Managers.lobby.server then
		Unit.flow_event(interactable_unit, event_name .. "_server")
		self:send_rpc_clients("rpc_trigger_complete", player_unit_id, interactable_unit_id)
		extension:set_interactor(nil)
	end

	Unit.flow_event(interactable_unit, event_name)
end

GameNetworkManager.rpc_bandage_request = function (self, sender, bandager_id, bandagee_id)
	local bandagee_unit = self._units[bandagee_id]
	local bandager_unit = self._units[bandager_id]

	if bandagee_unit and Unit.alive(bandagee_unit) and bandager_unit and Unit.alive(bandager_unit) then
		local damage_ext = ScriptUnit.extension(bandagee_unit, "damage_system")
		local can_be_bandaged = damage_ext:can_be_bandaged()

		if can_be_bandaged then
			InteractionHelper:confirm_request("bandage", sender, bandager_id)
			damage_ext:start_bandage(bandager_id, bandagee_id)

			return
		end
	end

	InteractionHelper:deny_request("bandage", sender, bandager_id)
end

GameNetworkManager.rpc_bandage_denied = function (self, sender, bandager_id)
	local bandager_unit = self._units[bandager_id]

	InteractionHelper:denied("bandage", ScriptUnit.extension(bandager_unit, "locomotion_system"))
end

GameNetworkManager.rpc_bandage_confirmed = function (self, sender, bandager_id)
	local bandager_unit = self._units[bandager_id]

	InteractionHelper:confirmed("bandage", ScriptUnit.extension(bandager_unit, "locomotion_system"))
end

GameNetworkManager.rpc_bandage_abort = function (self, sender, bandager_id, bandagee_id)
	local bandagee_unit = self._units[bandagee_id]

	if bandagee_unit and Unit.alive(bandagee_unit) then
		local damage_ext = ScriptUnit.extension(bandagee_unit, "damage_system")

		damage_ext:abort_bandage(bandager_id, bandagee_id)
	end
end

GameNetworkManager.rpc_revive_request = function (self, sender, reviver_id, revivee_id)
	local revivee_unit = self._units[revivee_id]
	local reviver_unit = self._units[reviver_id]

	if revivee_unit and Unit.alive(revivee_unit) and reviver_unit and Unit.alive(reviver_unit) then
		local damage_ext = ScriptUnit.extension(revivee_unit, "damage_system")
		local can_be_revived = damage_ext:can_be_revived()

		if can_be_revived then
			InteractionHelper:confirm_request("revive", sender, reviver_id)
			damage_ext:start_revive(reviver_id, revivee_id)

			return
		end
	end

	InteractionHelper:deny_request("revive", sender, reviver_id)
end

GameNetworkManager.rpc_revive_denied = function (self, sender, reviver_id)
	local reviver_unit = self._units[reviver_id]

	InteractionHelper:denied("revive", ScriptUnit.extension(reviver_unit, "locomotion_system"))
end

GameNetworkManager.rpc_revive_confirmed = function (self, sender, reviver_id)
	local reviver_unit = self._units[reviver_id]

	InteractionHelper:confirmed("revive", ScriptUnit.extension(reviver_unit, "locomotion_system"))
end

GameNetworkManager.rpc_revive_abort = function (self, sender, reviver_id, revivee_id)
	local revivee_unit = self._units[revivee_id]

	if revivee_unit and Unit.alive(revivee_unit) then
		local damage_ext = ScriptUnit.extension(revivee_unit, "damage_system")

		damage_ext:abort_revive(reviver_id, revivee_id)
	end
end

GameNetworkManager.rpc_abort_revive_teammate = function (self, sender, reviver_id, revivee_id)
	local revivee_unit = self._units[revivee_id]

	if revivee_unit and Unit.alive(revivee_unit) then
		local damage_ext = ScriptUnit.extension(revivee_unit, "damage_system")

		damage_ext:abort_revive(reviver_id, revivee_id)
	end
end

GameNetworkManager.rpc_completed_revive = function (self, sender, revivee_id)
	local revivee_unit = self._units[revivee_id]

	if revivee_unit and Unit.alive(revivee_unit) then
		local damage_ext = ScriptUnit.extension(revivee_unit, "damage_system")

		damage_ext:completed_revive()
	end
end

GameNetworkManager.rpc_bandage_completed_client = function (self, sender, bandagee_id)
	local bandagee_unit = self._units[bandagee_id]

	if bandagee_unit and Unit.alive(bandagee_unit) then
		local damage_ext = ScriptUnit.extension(bandagee_unit, "damage_system")

		damage_ext:rpc_bandage_completed_client()
	end
end

GameNetworkManager.rpc_start_revive_teammate = function (self, sender, reviver_id, revivee_id)
	local revivee_unit = self._units[revivee_id]
	local reviver_unit = self._units[reviver_id]

	if revivee_unit and Unit.alive(revivee_unit) and reviver_unit and Unit.alive(reviver_unit) then
		local damage_ext = ScriptUnit.extension(revivee_unit, "damage_system")

		damage_ext:start_revive(reviver_id, revivee_id)
	end
end

GameNetworkManager.rpc_request_flag_spawn = function (self, sender, picker_id, objective_index)
	local picker_unit = self._units[picker_id]
	local current_level = LevelHelper:current_level(self._world)
	local objective_unit = Level.unit_by_index(current_level, objective_index)

	if picker_unit and Unit.alive(picker_unit) and objective_unit and Unit.alive(objective_unit) then
		local objective_ext = ScriptUnit.extension(objective_unit, "objective_system")

		if objective_ext:can_spawn_flag(picker_unit) then
			local flag = objective_ext:spawn_flag(picker_unit)
			local flag_ext = ScriptUnit.extension(flag, "flag_system")

			flag_ext:pickup(picker_unit)

			local locomotion_ext = ScriptUnit.extension(picker_unit, "locomotion_system")

			locomotion_ext:rpc_flag_pickup_confirmed(flag)

			local flag_id = self:unit_game_object_id(flag)

			self:send_rpc_clients("rpc_flag_pickup_confirmed", picker_id, flag_id)

			return
		end
	end

	RPC.rpc_flag_pickup_denied(sender, picker_id)
end

GameNetworkManager.rpc_request_flag_pickup = function (self, sender, picker_id, flag_id)
	local flag_unit = self._units[flag_id]
	local picker_unit = self._units[picker_id]

	if picker_unit and Unit.alive(picker_unit) and flag_unit and Unit.alive(flag_unit) then
		local flag_ext = ScriptUnit.extension(flag_unit, "flag_system")

		if flag_ext:can_be_picked_up(picker_unit) then
			flag_ext:pickup(picker_unit)

			local locomotion_ext = ScriptUnit.extension(picker_unit, "locomotion_system")

			locomotion_ext:rpc_flag_pickup_confirmed(flag_unit)
			self:send_rpc_clients("rpc_flag_pickup_confirmed", picker_id, flag_id)

			return
		end
	end

	RPC.rpc_flag_pickup_denied(sender, picker_id)
end

GameNetworkManager.rpc_flag_pickup_confirmed = function (self, sender, picker_id, flag_id)
	local flag_unit = self._units[flag_id]
	local picker_unit = self._units[picker_id]
	local locomotion = ScriptUnit.extension(picker_unit, "locomotion_system")

	locomotion:rpc_flag_pickup_confirmed(flag_unit)

	local flag_ext = ScriptUnit.extension(flag_unit, "flag_system")

	flag_ext:pickup(picker_unit)
end

GameNetworkManager.rpc_flag_pickup_denied = function (self, sender, picker_id)
	local picker_unit = self._units[picker_id]
	local locomotion = ScriptUnit.extension(picker_unit, "locomotion_system")

	locomotion:rpc_flag_pickup_denied()
end

GameNetworkManager.rpc_request_flag_plant = function (self, sender, planter_id, flag_id, objective_index)
	local planter_unit = self._units[planter_id]
	local flag_unit = self._units[flag_id]
	local level = LevelHelper:current_level(self._world)
	local objective_unit = Level.unit_by_index(level, objective_index)

	if planter_unit and Unit.alive(planter_unit) and flag_unit and Unit.alive(flag_unit) and objective_unit and Unit.alive(objective_unit) then
		local objective_ext = ScriptUnit.extension(objective_unit, "objective_system")
		local flag_ext = ScriptUnit.extension(flag_unit, "flag_system")

		if objective_ext:can_plant_flag(planter_unit) and flag_ext:can_be_dropped(planter_unit) then
			objective_ext:set_current_planter(planter_unit)
			RPC.rpc_flag_plant_confirmed(sender, planter_id)

			return
		end
	end

	RPC.rpc_flag_plant_denied(sender, planter_id)
end

GameNetworkManager.rpc_flag_plant_denied = function (self, sender, planter_id)
	local planter_unit = self._units[planter_id]
	local locomotion = ScriptUnit.extension(planter_unit, "locomotion_system")

	locomotion:rpc_flag_plant_denied()
end

GameNetworkManager.rpc_flag_plant_confirmed = function (self, sender, picker_id)
	local picker_unit = self._units[picker_id]
	local locomotion = ScriptUnit.extension(picker_unit, "locomotion_system")

	locomotion:rpc_flag_plant_confirmed()
end

GameNetworkManager.rpc_flag_plant_complete = function (self, sender, planter_id, flag_id, objective_index)
	local planter_unit = self._units[planter_id]
	local flag_unit = self._units[flag_id]
	local objective_unit = Level.unit_by_index(ScriptWorld.level(self._world, LevelSettings[Managers.state.game_mode:level_key()].level_name), objective_index)

	if planter_unit and Unit.alive(planter_unit) and flag_unit and Unit.alive(flag_unit) and objective_unit and Unit.alive(objective_unit) then
		local objective_ext = ScriptUnit.extension(objective_unit, "objective_system")

		objective_ext:plant_flag(planter_unit)

		local locomotion_ext = ScriptUnit.extension(planter_unit, "locomotion_system")

		locomotion_ext:rpc_flag_plant_complete(flag_unit)

		local flag_ext = ScriptUnit.extension(flag_unit, "flag_system")

		flag_ext:die()
	end
end

GameNetworkManager.rpc_flag_plant_fail = function (self, sender, planter_id, objective_index)
	local level = LevelHelper:current_level(self._world)
	local objective_unit = Level.unit_by_index(level, objective_index)

	if objective_unit and Unit.alive(objective_unit) then
		local objective_ext = ScriptUnit.extension(objective_unit, "objective_system")

		objective_ext:set_current_planter(nil)
	end
end

GameNetworkManager.rpc_drop_flag = function (self, sender, dropper_id, flag_id)
	local flag_unit = self._units[flag_id]
	local dropper_unit = self._units[dropper_id]

	if flag_unit and Unit.alive(flag_unit) and dropper_unit and Unit.alive(dropper_unit) then
		local locomotion_ext = ScriptUnit.extension(dropper_unit, "locomotion_system")

		locomotion_ext:rpc_drop_flag(flag_unit)

		if Managers.lobby.server then
			self:send_rpc_clients_except("rpc_drop_flag", sender, dropper_id, flag_id)
		end
	end
end

GameNetworkManager.rpc_wpn_impact_char_no_pos_norm = function (self, sender, hit_unit_game_object_id, self_gear_game_object_id, target_type_id, direction_id, stun, damage, damage_without_armour, hit_zone_id, impact_direction)
	local character_unit = self._units[hit_unit_game_object_id]
	local gear_unit = self._units[self_gear_game_object_id]

	if not character_unit or not gear_unit then
		return
	end

	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_wpn_impact_char_no_pos_norm", sender, hit_unit_game_object_id, self_gear_game_object_id, target_type_id, direction_id, stun, damage, damage_without_armour, hit_zone_id, impact_direction)
	end

	local target_type = NetworkLookup.weapon_hit_parameters[target_type_id]
	local direction = NetworkLookup.weapon_hit_parameters[direction_id]

	WeaponHelper:weapon_impact_character(character_unit, gear_unit, target_type, direction, stun, damage, damage_without_armour, nil, nil, self._world, NetworkLookup.hit_zones[hit_zone_id], impact_direction)
end

GameNetworkManager.rpc_weapon_impact_character = function (self, sender, hit_unit_game_object_id, self_gear_game_object_id, target_type_id, direction_id, stun, damage, damage_without_armour, hit_zone_id, position, normal, impact_direction, weapon_damage_direction)
	local character_unit = self._units[hit_unit_game_object_id]
	local gear_unit = self._units[self_gear_game_object_id]

	if not character_unit or not gear_unit then
		return
	end

	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_weapon_impact_character", sender, hit_unit_game_object_id, self_gear_game_object_id, target_type_id, direction_id, stun, damage, damage_without_armour, hit_zone_id, position, normal, impact_direction, weapon_damage_direction)
	end

	local target_type = NetworkLookup.weapon_hit_parameters[target_type_id]
	local direction = NetworkLookup.weapon_hit_parameters[direction_id]

	WeaponHelper:weapon_impact_character(character_unit, gear_unit, target_type, direction, stun, damage, damage_without_armour, position, normal, self._world, NetworkLookup.hit_zones[hit_zone_id], impact_direction, weapon_damage_direction)
end

GameNetworkManager.rpc_add_instakill_push = function (self, sender, game_object_id, velocity, mass, hit_zone_id)
	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_add_instakill_push", sender, game_object_id, velocity, mass, hit_zone_id)
	end

	if sender ~= Network.peer_id() then
		local hit_zone_name = NetworkLookup.hit_zones[hit_zone_id]
		local unit = self._units[game_object_id]
		local locomotion_ext = ScriptUnit.extension(unit, "locomotion_system")

		locomotion_ext:rpc_add_instakill_push(velocity, mass, hit_zone_name)
	end
end

GameNetworkManager.rpc_mount_impact_character = function (self, sender, mount_id, victim_id, damage, position, normal, impulse)
	local mount_unit = self._units[mount_id]
	local victim_unit = self._units[victim_id]

	if mount_unit then
		ScriptUnit.extension(mount_unit, "locomotion_system"):impact_obstacle()
	end

	if victim_unit then
		WeaponHelper:mount_impact_character(victim_unit, damage, position, normal, self._world, "mount_impact", impulse)
	end
end

GameNetworkManager.rpc_shield_impact_character = function (self, sender, shield_unit_id, victim_id, damage, position, normal, hit_zone_id, impact_direction)
	local shield_unit = self._units[shield_unit_id]
	local victim_unit = self._units[victim_id]
	local hit_zone = NetworkLookup.hit_zones[hit_zone_id]

	if not shield_unit or not victim_unit then
		return
	end

	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_shield_impact_character", sender, shield_unit_id, victim_id, damage, position, normal, hit_zone_id, impact_direction)
	end

	WeaponHelper:shield_impact_character(victim_unit, damage, position, normal, self._world, hit_zone, impact_direction)
end

GameNetworkManager.rpc_push_impact_character = function (self, sender, shield_unit_id, victim_id, damage, position, normal, hit_zone_id, impact_direction)
	local shield_unit = self._units[shield_unit_id]
	local victim_unit = self._units[victim_id]
	local hit_zone = NetworkLookup.hit_zones[hit_zone_id]

	if not shield_unit or not victim_unit then
		return
	end

	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_push_impact_character", sender, shield_unit_id, victim_id, damage, position, normal, hit_zone_id, impact_direction)
	end

	WeaponHelper:push_impact_character(victim_unit, damage, position, normal, self._world, hit_zone, impact_direction)
end

GameNetworkManager.rpc_rush_impact_character = function (self, sender, shield_unit_id, victim_id, position, normal, impact_direction)
	local shield_unit = self._units[shield_unit_id]
	local victim_unit = self._units[victim_id]

	if not shield_unit or not victim_unit then
		return
	end

	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_rush_impact_character", sender, shield_unit_id, victim_id, position, normal, impact_direction)
	end

	WeaponHelper:rush_impact_character(victim_unit, position, normal, self._world, impact_direction)
end

GameNetworkManager.rpc_weapon_impact_gear = function (self, sender, hit_gear_game_object_id, self_gear_game_object_id, target_type_id, direction_id, damage, damage_without_armour, fully_charged_attack, position, normal)
	local hit_gear_unit = self._units[hit_gear_game_object_id]

	if not Unit.alive(hit_gear_unit) then
		if script_data.network_debug then
			print("[GameNetworkManager:rpc_weapon_impact_gear] Disregarding impact to no longer existing gear with game object id: ", hit_gear_game_object_id)
		end

		return
	end

	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_weapon_impact_gear", sender, hit_gear_game_object_id, self_gear_game_object_id, target_type_id, direction_id, damage, damage_without_armour, fully_charged_attack, position, normal)
	end

	local gear_unit = self._units[self_gear_game_object_id]
	local target_type = NetworkLookup.weapon_hit_parameters[target_type_id]
	local direction = NetworkLookup.weapon_hit_parameters[direction_id]

	WeaponHelper:gear_impact(hit_gear_unit, gear_unit, target_type, direction, damage, damage_without_armour, position, normal, self._world, fully_charged_attack)
end

GameNetworkManager.rpc_handgonne_impact_character = function (self, sender, hit_unit_game_object_id, position, damage, stun, hit_zone_id, impact_direction)
	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_handgonne_impact_character", sender, hit_unit_game_object_id, position, damage, stun, hit_zone_id, impact_direction)
	end

	local character_unit = self._units[hit_unit_game_object_id]

	WeaponHelper:handgonne_impact_character(character_unit, position, damage, self._world, stun, NetworkLookup.hit_zones[hit_zone_id], impact_direction)
end

GameNetworkManager.rpc_spawn_player_unit = function (self, sender, player_id, pos, rot, ghost_mode, profile_index)
	local player_manager = Managers.player
	local players = player_manager:players()
	local max_players = player_manager.MAX_PLAYERS

	for player_index = 1, max_players do
		if player_manager:player_exists(player_index) then
			local player = player_manager:player(player_index)

			if player.temp_random_user_id == player_id then
				Managers.state.spawn:rpc_spawn_player_unit(player, pos, rot, ghost_mode, profile_index > 0 and profile_index or nil)

				return
			end
		end
	end
end

GameNetworkManager.rpc_request_leave_ghost_mode = function (self, sender, player_id, player_unit_id)
	local player = Managers.player:player(player_id)
	local player_unit = self._units[player_unit_id]

	Managers.state.spawn:rpc_request_leave_ghost_mode(sender, player, player_unit)
end

GameNetworkManager.rpc_leave_ghost_mode = function (self, sender, player_id, player_unit_id)
	local player_unit = self._units[player_unit_id]

	if not player_unit then
		return
	end

	local player_manager = Managers.player
	local players = player_manager:players()
	local max_players = player_manager.MAX_PLAYERS

	for player_index = 1, max_players do
		if player_manager:player_exists(player_index) then
			local player = player_manager:player(player_index)

			if player.temp_random_user_id == player_id then
				Managers.state.spawn:rpc_leave_ghost_mode(player, player_unit)

				return
			end
		end
	end
end

GameNetworkManager.rpc_request_area_spawn_target = function (self, sender, player_id, area_id)
	local player_manager = Managers.player
	local player = player_manager:player(player_id)

	Managers.state.spawn:rpc_request_area_spawn_target(player, area_id)
end

GameNetworkManager.rpc_request_unconf_squad_spawn = function (self, sender, player_id, unit_id)
	local squad_unit = self._units[unit_id]

	if squad_unit then
		local player = Managers.player:player(player_id)

		Managers.state.spawn:rpc_request_unconf_squad_spawn(player, squad_unit)
	end
end

GameNetworkManager.rpc_request_squad_spawn_target = function (self, sender, player_id, unit_id)
	local squad_unit = self._units[unit_id]

	if squad_unit then
		local player = Managers.player:player(player_id)

		Managers.state.spawn:rpc_request_squad_spawn_target(player, squad_unit)
	end
end

GameNetworkManager.rpc_squad_spawn_target_set = function (self, sender, player_id, target_game_object_id)
	local target_unit = self._units[target_game_object_id]

	if not target_unit then
		return
	end

	local player_manager = Managers.player
	local players = player_manager:players()
	local max_players = player_manager.MAX_PLAYERS

	for player_index = 1, max_players do
		if player_manager:player_exists(player_index) then
			local player = player_manager:player(player_index)

			if player.temp_random_user_id == player_id then
				Managers.state.spawn:rpc_squad_spawn_target_set(player, target_unit)

				return
			end
		end
	end
end

GameNetworkManager.rpc_unconf_sq_spawn_target_set = function (self, sender, player_id, target_game_object_id)
	local target_unit = self._units[target_game_object_id]

	if not target_unit then
		return
	end

	local player_manager = Managers.player
	local players = player_manager:players()
	local max_players = player_manager.MAX_PLAYERS

	for player_index = 1, max_players do
		if player_manager:player_exists(player_index) then
			local player = player_manager:player(player_index)

			if player.temp_random_user_id == player_id then
				Managers.state.spawn:rpc_unconf_sq_spawn_target_set(player, target_unit)

				return
			end
		end
	end
end

GameNetworkManager.rpc_player_unit_despawned = function (self, sender, player_id)
	local player = Managers.player:player(self:temp_player_index(player_id))

	Managers.state.spawn:rpc_player_unit_despawned(player)
end

GameNetworkManager.rpc_spawn_target_denied = function (self, sender)
	Managers.state.event:trigger("spawn_target_denied")
end

GameNetworkManager.rpc_request_join_team = function (self, sender, player_id, team_name_id)
	local player = Managers.player:player(player_id)
	local team_name = NetworkLookup.team[team_name_id]

	Managers.state.team:request_join_team(player, team_name)
end

GameNetworkManager.rpc_join_team_confirmed = function (self, sender)
	Managers.state.event:trigger("join_team_confirmed")
end

GameNetworkManager.rpc_join_team_denied = function (self, sender)
	Managers.state.event:trigger("join_team_denied")
end

GameNetworkManager.rpc_create_squad_area_buff = function (self, sender, player_id, owning_unit_id, buff_type_id)
	local player = Managers.player:player(self:temp_player_index(player_id))
	local owning_unit = self._units[owning_unit_id]
	local buff_type = NetworkLookup.buff_types[buff_type_id]

	AreaBuffHelper:play_squad_area_buff_voice_over(owning_unit, buff_type, self._world, sender)
	AreaBuffHelper:create_squad_area_buff(player, owning_unit, buff_type)
end

GameNetworkManager.rpc_play_squad_area_buff_vo = function (self, sender, buff_type_id, unit_id)
	local unit = self._units[unit_id]
	local buff_type = NetworkLookup.buff_types[buff_type_id]

	AreaBuffHelper:play_squad_area_buff_voice_over(unit, buff_type, self._world)
end

GameNetworkManager.rpc_game_server_set = function (self, sender, is_set)
	Managers.lobby:set_game_server_set(is_set)
end

GameNetworkManager.gm_event_flag_planted = function (self, planter_player, interactable_unit)
	local level = LevelHelper:current_level(self._world)
	local unit_index = Level.unit_index(level, interactable_unit)
	local player_id = planter_player:player_id()

	self:send_rpc_clients("rpc_gm_event_flag_planted", player_id, unit_index)
end

GameNetworkManager.rpc_gm_event_flag_planted = function (self, sender, player_id, interactable_unit_index)
	local planter_player = Managers.player:player(self:temp_player_index(player_id))
	local level = LevelHelper:current_level(self._world)
	local interactable_unit = Level.unit_by_index(level, interactable_unit_index)

	Managers.state.game_mode:trigger_event("flag_planted", planter_player, interactable_unit)
end

GameNetworkManager.gm_event_battle_tiebreak = function (self)
	self:send_rpc_clients("rpc_gm_event_battle_tiebreak")
end

GameNetworkManager.rpc_gm_event_battle_tiebreak = function (self, sender)
	Managers.state.game_mode:trigger_event("battle_tiebreak")
end

GameNetworkManager.gm_event_objective_captured = function (self, capturing_player, captured_unit)
	local level = LevelHelper:current_level(self._world)
	local unit_index = Level.unit_index(level, captured_unit)
	local player_id = capturing_player:player_id()

	self:send_rpc_clients("rpc_gm_event_objective_captured", player_id, unit_index)
end

GameNetworkManager.rpc_gm_event_objective_captured = function (self, sender, player_id, capured_unit_index)
	local capturing_player = Managers.player:player(self:temp_player_index(player_id))
	local level = LevelHelper:current_level(self._world)
	local captured_unit = Level.unit_by_index(level, capured_unit_index)

	Managers.state.game_mode:trigger_event("objective_captured", capturing_player, captured_unit)
end

GameNetworkManager.gm_event_time_extended = function (self, side, extend_time)
	local side_id = NetworkLookup.team[side]

	self:send_rpc_clients("rpc_gm_event_time_extended", side_id, extend_time)
end

GameNetworkManager.rpc_gm_event_time_extended = function (self, sender, side_id, extend_time)
	local side = NetworkLookup.team[side_id]

	Managers.state.game_mode:trigger_event("time_extended", side, extend_time)
end

GameNetworkManager.gm_event_assault_announcement = function (self, side, announcement)
	local side_id = NetworkLookup.team[side]
	local announcement_id = NetworkLookup.assault_announcements[announcement]

	self:send_rpc_clients("rpc_gm_event_assault_announcement", side_id, announcement_id)
end

GameNetworkManager.rpc_gm_event_assault_announcement = function (self, sender, side_id, announcement_id)
	local side = NetworkLookup.team[side_id]
	local announcement = NetworkLookup.assault_announcements[announcement_id]

	Managers.state.game_mode:trigger_event("assault_announcement", side, announcement)
end

GameNetworkManager.gm_event_objective_captured_assist = function (self, assist_player, captured_unit)
	local level = LevelHelper:current_level(self._world)
	local unit_index = Level.unit_index(level, captured_unit)
	local player_id = assist_player:player_id()

	self:send_rpc_clients("rpc_gm_event_objective_captured_assist", player_id, unit_index)
end

GameNetworkManager.rpc_gm_event_objective_captured_assist = function (self, sender, player_id, captured_unit_index)
	local assist_player = Managers.player:player(self:temp_player_index(player_id))
	local level = LevelHelper:current_level(self._world)
	local captured_unit = Level.unit_by_index(level, captured_unit_index)

	Managers.state.game_mode:trigger_event("objective_captured_assist", assist_player, captured_unit)
end

GameNetworkManager.gm_event_end_conditions_met = function (self, winning_team_name, red_team_score, white_team_score, end_of_round)
	self:send_rpc_clients("rpc_gm_event_end_conditions_met", NetworkLookup.team[winning_team_name], red_team_score, white_team_score, end_of_round)
end

GameNetworkManager.rpc_gm_event_end_conditions_met = function (self, sender, winning_team_name, red_team_score, white_team_score, end_of_round)
	Managers.state.game_mode:trigger_event("end_conditions_met", NetworkLookup.team[winning_team_name], red_team_score, white_team_score, end_of_round)
end

GameNetworkManager.rpc_write_network_dump_tag = function (self, sender, tag_id)
	Network.write_dump_tag(NetworkLookup.network_dump_tags[tag_id] .. " [" .. sender .. "]")
end

GameNetworkManager.update_combat_log = function (self, attacking_player, victim_player, gear_name)
	if Managers.lobby.server then
		self:send_rpc_clients("rpc_update_combat_log", attacking_player:player_id(), victim_player:player_id(), NetworkLookup.gear_names[gear_name])
	end

	Managers.state.event:trigger("update_combat_log", attacking_player, victim_player, gear_name)
end

GameNetworkManager.rpc_update_combat_log = function (self, sender, attacking_player_id, victim_player_id, gear_name_id)
	local attacking_player = Managers.player:player(self:temp_player_index(attacking_player_id))
	local victim_player = Managers.player:player(self:temp_player_index(victim_player_id))
	local gear_name = NetworkLookup.gear_names[gear_name_id]

	Managers.state.event:trigger("update_combat_log", attacking_player, victim_player, gear_name)
end

GameNetworkManager.rpc_surface_mtr_fx = function (self, sender, effect_name_id, unit_game_object_id, position, rotation, normal)
	local unit = self._units[unit_game_object_id]

	if not Unit.alive(unit) then
		return
	end

	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_surface_mtr_fx", sender, effect_name_id, unit_game_object_id, position, rotation, normal)
	end

	local effect_name = NetworkLookup.surface_material_effects[effect_name_id]

	EffectHelper.play_surface_material_effects(effect_name, self._world, unit, position, rotation, normal)
end

GameNetworkManager.rpc_surface_mtr_fx_lvl_unit = function (self, sender, effect_name_id, unit_level_index, position, rotation, normal)
	local level = LevelHelper:current_level(self._world)
	local unit = Level.unit_by_index(level, unit_level_index)

	if not Unit.alive(unit) then
		return
	end

	if Managers.lobby.server then
		self:send_rpc_clients_except("rpc_surface_mtr_fx_lvl_unit", sender, effect_name_id, unit_level_index, position, rotation, normal)
	end

	local effect_name = NetworkLookup.surface_material_effects[effect_name_id]

	EffectHelper.play_surface_material_effects(effect_name, self._world, unit, position, rotation, normal)
end

GameNetworkManager.send_rpc_server = function (self, rpc_name, ...)
	local rpc = RPC[rpc_name]

	fassert(rpc, "[GameNetworkManager:send_rpc_server()] rpc does not exist %q", rpc_name)

	if Managers.lobby.server then
		self[rpc_name](self, Network.peer_id(), ...)
	elseif not self._lobby:game_session_host() then
		print("[ERROR] Game server not set when trying to send rpc \"" .. tostring(rpc_name) .. "\" to server.")
	else
		rpc(self._lobby:game_session_host(), ...)
	end
end

GameNetworkManager.send_rpc_clients = function (self, rpc_name, ...)
	if not self._game then
		print("[ERROR] Game server not set when trying to send rpc \"" .. tostring(rpc_name) .. "\" to clients.")

		return
	end

	local rpc = RPC[rpc_name]

	assert(rpc, "[GameNetworkManager:send_rpc_clients()] rpc does not exist: " .. tostring(rpc_name))

	for _, player in ipairs(GameSession.other_peers(self._game)) do
		if not self._object_synchronizing_clients[player] then
			rpc(player, ...)
		elseif script_data.network_debug then
			print("[GameNetworkManager:send_rpc_clients()] Did not send rpc", rpc_name, "to", player, " since it is still synchronizing objects.")
		end
	end
end

GameNetworkManager.send_rpc_clients_except = function (self, rpc_name, except, ...)
	if not self._game then
		print("[ERROR] Game server no set when trying to send rpc \"" .. tostring(rpc_name) .. "\" to clients.")

		return
	end

	local rpc = RPC[rpc_name]

	assert(rpc, "[GameNetworkManager:send_rpc_clients_except()] rpc does not exist: " .. tostring(rpc_name))

	for _, player in ipairs(GameSession.other_peers(self._game)) do
		if player ~= except and not self._object_synchronizing_clients[player] then
			rpc(player, ...)
		elseif script_data.network_debug and self._object_synchronizing_clients[player] then
			print("[GameNetworkManager:send_rpc_clients_except()] Did not send rpc", rpc_name, "to", player, " since it is still synchronizing objects.")
		end
	end
end

GameNetworkManager.send_rpc_all = function (self, rpc_name, ...)
	if not self._game then
		print("[ERROR] Game server no set when trying to send rpc \"" .. tostring(rpc_name) .. "\" to all.")

		return
	end

	local rpc = RPC[rpc_name]

	assert(rpc, "[GameNetworkManager:send_rpc_all()] rpc does not exist: " .. tostring(rpc_name))

	for _, player in ipairs(GameSession.peers(self._game)) do
		if not self._object_synchronizing_clients[player] then
			rpc(player, ...)
		elseif script_data.network_debug then
			print("[GameNetworkManager:send_rpc_all()] Did not send rpc", rpc_name, "to", player, " since it is still synchronizing objects.")
		end
	end
end

GameNetworkManager.send_rpc_all_except = function (self, rpc_name, except, ...)
	if not self._game then
		print("[ERROR] Game server no set when trying to send rpc \"" .. tostring(rpc_name) .. "\" to all.")

		return
	end

	local rpc = RPC[rpc_name]

	assert(rpc, "[GameNetworkManager:send_rpc_all_except()] rpc does not exist: " .. tostring(rpc_name))

	for _, player in ipairs(GameSession.peers(self._game)) do
		if player ~= except and not self._object_synchronizing_clients[player] then
			rpc(player, ...)
		elseif script_data.network_debug and self._object_synchronizing_clients[player] then
			print("[GameNetworkManager:send_rpc_all_except()] Did not send rpc", rpc_name, "to", player, " since it is still synchronizing objects.")
		end
	end
end

GameNetworkManager.rpc_set_game_speed = function (self, sender, multiplier)
	if Managers.lobby.server then
		self:send_rpc_clients("rpc_set_game_speed", multiplier)
	end

	Application.set_time_step_policy("external_multiplier", multiplier)
end

GameNetworkManager.rpc_toggle_disable_damage = function (self, sender)
	script_data.disable_damage = not script_data.disable_damage
end

GameNetworkManager.rpc_toggle_unlimited_ammo = function (self, sender, bool)
	if Managers.lobby.server then
		script_data.unlimited_ammo = not script_data.unlimited_ammo

		self:send_rpc_clients("rpc_toggle_unlimited_ammo", script_data.unlimited_ammo)
	else
		script_data.unlimited_ammo = bool
	end
end

GameNetworkManager.rpc_teleport_all_to = function (self, sender, position, rotation, camera_rotation)
	if Managers.lobby.server then
		self:send_rpc_clients("rpc_teleport_all_to", position, rotation, camera_rotation)
	end

	Managers.state.event:trigger("teleport_all_to", position, rotation, camera_rotation)
end

GameNetworkManager.rpc_teleport_unit_to = function (self, sender, unit_id, position, rotation, camera_rotation)
	local unit = self._units[unit_id]

	if Unit.alive(unit) then
		if Managers.lobby.server then
			self:send_rpc_clients("rpc_teleport_unit_to", unit_id, position, rotation, camera_rotation)
		end

		Managers.state.event:trigger("teleport_unit_to", unit, position, rotation, camera_rotation)
	end
end

GameNetworkManager.rpc_teleport_team_to = function (self, sender, team_id, position, rotation, camera_rotation)
	if Managers.lobby.server then
		self:send_rpc_clients("rpc_teleport_team_to", team_id, position, rotation, camera_rotation)
	end

	Managers.state.event:trigger("teleport_team_to", NetworkLookup.team[team_id], position, rotation, camera_rotation)
end

GameNetworkManager.rpc_set_team_object_set_visible = function (self, sender, key, visibility)
	Managers.state.game_mode:rpc_set_team_object_set_visible(key, visibility)
end

GameNetworkManager.rpc_set_object_set_variation = function (self, sender, key, team_name_id)
	Managers.state.game_mode:rpc_set_object_set_variation(key, NetworkLookup.team[team_name_id])
end

GameNetworkManager.rpc_rcon = function (self, sender, hash, command)
	local rcon_settings = Managers.admin:settings().rcon
	local is_rcon_admin = sender == Managers.admin:rcon_admin()

	if rcon_settings and (hash == Application.make_hash(rcon_settings.password) or is_rcon_admin) then
		CommandWindow.print("[RCON] " .. command)

		local player = self:player_from_peer_id(sender)
		local success, message = Managers.command_parser:execute(command, player)

		if success then
			Managers.chat:send_chat_message(1, message, "rpc_rcon_chat_message")
		elseif message then
			RPC.rpc_rcon_reply(sender, message)
		else
			local message = sprintf("Unrecognized RCON command %q", command)

			RPC.rpc_rcon_reply(sender, message)
		end
	else
		CommandWindow.print("[RCON] Password check failed.")
	end
end

GameNetworkManager.rpc_rcon_logged_in = function (self, sender, player_id)
	local player = Managers.player:player(self:temp_player_index(player_id))

	if player then
		player.rcon_admin = true
	end
end

GameNetworkManager.rpc_rcon_logged_out = function (self, sender, player_id)
	local player = Managers.player:player(self:temp_player_index(player_id))

	if player then
		player.rcon_admin = false
	end
end

GameNetworkManager.rpc_admin_chat_message = function (self, sender, channel_id, message_sender, message)
	Managers.state.event:trigger("event_admin_chat_message", channel_id, message_sender, message)
end

GameNetworkManager.rpc_rcon_chat_message = function (self, sender, channel_id, message_sender, message)
	Managers.state.event:trigger("event_rcon_chat_message", channel_id, message_sender, message)
end

GameNetworkManager.rpc_set_zone_name = function (self, sender, level_unit_index, zone_name)
	local level = LevelHelper:current_level(self._world)
	local unit = Level.unit_by_index(level, level_unit_index)

	if Unit.alive(unit) then
		local ext = ScriptUnit.extension(unit, "objective_system")

		ext:set_zone_name(zone_name)
	end
end

GameNetworkManager.rpc_vote_kick = function (self, sender, kick_peer_id, vote_player_id)
	local function success_callback(kick_peer_id)
		Managers.admin:kick_player(kick_peer_id)
	end

	local voter = Managers.player:player(self:temp_player_index(vote_player_id))

	Managers.state.voting:start_vote("kick", voter, kick_peer_id)
end

GameNetworkManager.rpc_vote = function (self, sender, vote_cast_bool, voter_player_id, id)
	local voter = Managers.player:player(self:temp_player_index(voter_player_id))

	Managers.state.voting:rpc_vote(vote_cast_bool and "yes" or "no", voter, id)
end

GameNetworkManager.cb_vote_destroyed = function (self, id)
	if Managers.lobby.server then
		-- Nothing
	else
		Managers.state.voting:client_vote_destroyed(id)
	end
end

GameNetworkManager.cb_vote_created = function (self, id)
	Managers.state.voting:client_vote_created(id)
end

GameNetworkManager.is_valid_peer = function (self, peer_id)
	local players = Managers.player:players()

	for _, player in pairs(players) do
		if player:network_id() == peer_id then
			return true
		end
	end

	return false
end

GameNetworkManager.player_from_peer_id = function (self, peer_id)
	for _, player in pairs(Managers.player:players()) do
		if player:network_id() == peer_id then
			return player
		end
	end
end

GameNetworkManager.rpc_rcon_reply = function (self, sender, message)
	Managers.state.hud:output_console_text(message, Vector3(255, 255, 255), 5)
end

GameNetworkManager.update_round_time_report = function (self, dt, t)
	local player = Managers.player:player(1)

	player.round_time_reported = player.round_time_reported or t

	if t >= player.round_time_reported + 3 then
		local round_time = Managers.time:time("round")

		self:send_rpc_server("rpc_round_time_report", player.game_object_id, round_time)

		player.round_time_reported = t
	end
end

GameNetworkManager.rpc_round_time_report = function (self, sender, player_id, round_time)
	round_time = round_time + Network.ping(sender) / 2

	local player = Managers.player:player(self:temp_player_index(player_id))

	Managers.state.event:trigger("check_speedhack", player, round_time)
end

GameNetworkManager.rpc_tag_speedhack = function (self, sender)
	Managers.backend:update_profile("speedhack")
end

GameNetworkManager.rpc_interact_assault_gate = function (self, sender, game_object_id)
	local level = LevelHelper:current_level(self._world)
	local level_unit_index = GameSession.game_object_field(self._game, game_object_id, "level_unit_index")
	local unit = Level.unit_by_index(level, level_unit_index)

	ScriptUnit.extension(unit, "objective_system"):interact_gate()
end

GameNetworkManager.rpc_open_assault_gate = function (self, sender, game_object_id, interaction_timer)
	local level = LevelHelper:current_level(self._world)
	local level_unit_index = GameSession.game_object_field(self._game, game_object_id, "level_unit_index")
	local unit = Level.unit_by_index(level, level_unit_index)

	ScriptUnit.extension(unit, "objective_system"):open_gate(interaction_timer)
end

GameNetworkManager.rpc_close_assault_gate = function (self, sender, game_object_id, interaction_timer)
	local level = LevelHelper:current_level(self._world)
	local level_unit_index = GameSession.game_object_field(self._game, game_object_id, "level_unit_index")
	local unit = Level.unit_by_index(level, level_unit_index)

	ScriptUnit.extension(unit, "objective_system"):close_gate(interaction_timer)
end

GameNetworkManager.rpc_synch_assault_gate = function (self, sender, game_object_id, gate_state)
	local level = LevelHelper:current_level(self._world)
	local level_unit_index = GameSession.game_object_field(self._game, game_object_id, "level_unit_index")
	local unit = Level.unit_by_index(level, level_unit_index)

	ScriptUnit.extension(unit, "objective_system"):rpc_synch_assault_gate(NetworkLookup.gate_states[gate_state])
end

GameNetworkManager.rpc_raise_assault_ladder = function (self, sender, game_object_id)
	local level = LevelHelper:current_level(self._world)
	local level_unit_index = GameSession.game_object_field(self._game, game_object_id, "level_unit_index")
	local unit = Level.unit_by_index(level, level_unit_index)

	ScriptUnit.extension(unit, "objective_system"):rpc_raise_assault_ladder()
end

GameNetworkManager.rpc_synch_assault_ladder = function (self, sender, game_object_id, raised)
	local level = LevelHelper:current_level(self._world)
	local level_unit_index = GameSession.game_object_field(self._game, game_object_id, "level_unit_index")
	local unit = Level.unit_by_index(level, level_unit_index)

	ScriptUnit.extension(unit, "objective_system"):rpc_synch_assault_ladder(raised)
end

GameNetworkManager.rpc_payload_target_reached = function (self, sender, game_object_id, auto_reached)
	local level = LevelHelper:current_level(self._world)
	local level_unit_index = GameSession.game_object_field(self._game, game_object_id, "level_unit_index")
	local unit = Level.unit_by_index(level, level_unit_index)

	if auto_reached then
		Unit.flow_event(unit, "lua_target_auto_reached_all")
	else
		Unit.flow_event(unit, "lua_target_reached_all")
	end
end

GameNetworkManager.rpc_award_daily_win_bonus = function (self, sender, win_bonus_amount)
	Managers.state.event:trigger("daily_win_bonus_awarded", win_bonus_amount)
end

GameNetworkManager.rpc_award_round_win_bonus = function (self, sender, win_bonus_amount)
	Managers.state.event:trigger("round_win_bonus_awarded", win_bonus_amount)
end

GameNetworkManager.rpc_map_rotation = function (self, sender)
	local maps = Managers.admin:settings().map_rotation.maps
	local map_rotation_string = ""

	for _, map in pairs(maps) do
		map_rotation_string = map_rotation_string .. sprintf("MAP: %s GAME MODE: %s\n", LevelSettings[map.level].game_server_map_name, map.game_mode)
	end

	RPC.rpc_map_rotation_reply(sender, map_rotation_string)
end

GameNetworkManager.rpc_map_rotation_reply = function (self, sender, map_rotation_string)
	Managers.state.hud:output_console_text("--- Map Rotation ---")

	local maps = string.split(map_rotation_string, "\n")

	for _, map in pairs(maps) do
		Managers.state.hud:output_console_text(map)
	end
end

GameNetworkManager.rpc_vote_map = function (self, sender, voter_id, map_game_mode_pair)
	if Managers.state.voting:vote_in_progress() then
		RPC.rpc_vote_map_error(sender, "Vote is already in progress")

		return
	end

	map_game_mode_pair = (map_game_mode_pair or ""):lower()

	local map, game_mode = unpack_string(map_game_mode_pair)

	if not map then
		RPC.rpc_vote_map_error(sender, "Map name missing. For example: /vote_map St_Albans tdm")

		return
	end

	if not game_mode then
		RPC.rpc_vote_map_error(sender, "Game mode missing. For example: /vote_map St_Albans tdm")

		return
	end

	local level_key = server_map_name_to_level_key(map)

	if not level_key then
		RPC.rpc_vote_map_error(sender, sprintf("Invalid map name: %s", map))

		return
	end

	local settings = Managers.admin:map_rotation_settings(level_key, game_mode)

	if not settings then
		RPC.rpc_vote_map_error(sender, sprintf("Map %q and game mode %q is not defined in map_rotations settings file. Run /list_levels to see which maps are available.", map, game_mode))

		return
	end

	local voter = Managers.player:player(self:temp_player_index(voter_id))

	Managers.state.voting:start_vote("change_level", voter, map_game_mode_pair)
end

GameNetworkManager.rpc_vote_map_error = function (self, sender, error_message)
	Managers.state.hud:output_console_text(error_message)
end
