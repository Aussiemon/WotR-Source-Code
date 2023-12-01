-- chunkname: @scripts/managers/network/menu_network_manager.lua

require("scripts/network_lookup/network_lookup")

MenuNetworkManager = class(MenuNetworkManager)

local Lobby = LanLobbyStateMachine

MenuNetworkManager.init = function (self, state, lobby)
	self._state = state
	self._lobby = lobby
	self._notified_clients = {}

	if self._lobby then
		Network.set_pong_timeout(GameSettingsDevelopment.network_timeout)

		local members = Managers.lobby:lobby_members()

		for _, member in pairs(members) do
			if member ~= Network.peer_id() then
				self._notified_clients[member] = true
			end
		end
	end

	Managers.chat:register_chat_rpc_callbacks(self)
end

MenuNetworkManager.update = function (self, dt)
	Network.update(dt, self)
end

MenuNetworkManager.destroy = function (self)
	return
end

MenuNetworkManager.rpc_notify_lobby_joined = function (self, sender)
	local is_dedicated = script_data.settings.dedicated_server

	if is_dedicated and Managers.admin:is_player_banned(sender) then
		RPC.rpc_denied_to_enter_game(sender, "banned")
	elseif is_dedicated and Managers.admin:is_server_locked() then
		RPC.rpc_denied_to_enter_game(sender, "locked")
	elseif is_dedicated and not Managers.admin:check_reserved_slots(sender) then
		RPC.rpc_denied_to_enter_game(sender, "reserved_slot")
	else
		self._notified_clients[sender] = true
	end
end

MenuNetworkManager.rpc_load_level = function (self, sender, level_key, game_mode_key, game_start_countdown, win_score, time_limit)
	self._drop_in_settings = {
		level_cycle_count = 1,
		level_key = NetworkLookup.level_keys[level_key],
		game_mode_key = NetworkLookup.game_mode_keys[game_mode_key],
		win_score = win_score,
		time_limit = time_limit,
		level_cycle = {
			{
				level = NetworkLookup.level_keys[level_key],
				game_mode = NetworkLookup.game_mode_keys[game_mode_key],
				win_score = win_score,
				time_limit = time_limit
			}
		},
		game_start_countdown = game_start_countdown
	}
end

MenuNetworkManager.rpc_load_next_level = function (self, sender, level_key, game_mode_key, game_start_countdown, win_score, time_limit)
	self._drop_in_settings = {
		level_cycle_count = 1,
		level_key = NetworkLookup.level_keys[level_key],
		game_mode_key = NetworkLookup.game_mode_keys[game_mode_key],
		game_start_countdown = game_start_countdown,
		win_score = win_score,
		time_limit = time_limit,
		level_cycle = {
			{
				level = NetworkLookup.level_keys[level_key],
				game_mode = NetworkLookup.game_mode_keys[game_mode_key],
				win_score = win_score,
				time_limit = time_limit
			}
		}
	}
end

MenuNetworkManager.rpc_reload_level = function (self)
	return
end

MenuNetworkManager.rpc_permission_to_enter_game = function (self, sender)
	self._state.parent.permission_to_enter_game = true
end

MenuNetworkManager.rpc_denied_to_enter_game = function (self, sender, reason)
	print("Denied to enter lobby. Reason: ", reason)
	Managers.state.event:trigger("denied_to_enter_game", reason)
end

MenuNetworkManager.drop_in_settings = function (self)
	local drop_in_settings = self._drop_in_settings

	self._drop_in_settings = nil

	return drop_in_settings
end

MenuNetworkManager.start_server_game = function (self, level_key, game_mode_key, win_score, time_limit)
	fassert(Managers.lobby.server, "[MenuNetworkManager] Server game can only be started from player registered as server in lobby")

	local game_start_countdown = GameSettingsDevelopment.game_start_countdown

	self:rpc_load_level(Network.peer_id(), NetworkLookup.level_keys[level_key], NetworkLookup.game_mode_keys[game_mode_key], game_start_countdown, win_score, time_limit)

	for member, _ in pairs(self._notified_clients) do
		RPC.rpc_load_level(member, NetworkLookup.level_keys[level_key], NetworkLookup.game_mode_keys[game_mode_key], game_start_countdown, win_score, time_limit)
	end
end

MenuNetworkManager.rpc_game_server_set = function (self, sender, is_set)
	Managers.lobby:set_game_server_set(is_set)
end
