-- chunkname: @scripts/managers/network/loading_network_manager.lua

require("scripts/network_lookup/network_lookup")

LoadingNetworkManager = class(LoadingNetworkManager)

local Lobby = LanLobbyStateMachine

LoadingNetworkManager.init = function (self, state, lobby)
	self._state = state

	Managers.chat:register_chat_rpc_callbacks(self)
end

LoadingNetworkManager.update = function (self, dt)
	Network.update(dt, self)
end

LoadingNetworkManager.destroy = function (self)
	return
end

LoadingNetworkManager.rpc_permission_to_enter_game = function (self)
	self._state.parent.permission_to_enter_game = true
end

LoadingNetworkManager.rpc_denied_to_enter_game = function (self, sender, reason)
	print("Denied to enter lobby. Reason: ", reason)
	Managers.state.event:trigger("denied_to_enter_game", reason)
end

LoadingNetworkManager.rpc_drop_in = function (self, sender)
	return
end

LoadingNetworkManager.rpc_load_next_level = function (self, sender, level_key, game_mode_key, game_start_countdown, win_score, time_limit)
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

LoadingNetworkManager.rpc_reload_level = function (self)
	return
end

LoadingNetworkManager.drop_in_settings = function (self)
	local drop_in_settings = self._drop_in_settings

	self._drop_in_settings = nil

	return drop_in_settings
end

LoadingNetworkManager.rpc_notify_lobby_joined = function (self, sender)
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
	end
end

LoadingNetworkManager.rpc_game_server_set = function (self, sender, is_set)
	Managers.lobby:set_game_server_set(is_set)
end
