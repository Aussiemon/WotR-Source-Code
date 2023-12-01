-- chunkname: @scripts/managers/network/automatic_dedicated_server_join_network_manager.lua

require("scripts/network_lookup/network_lookup")

AutomaticDedicatedServerJoinNetworkManager = class(AutomaticDedicatedServerJoinNetworkManager)

local Lobby = LanLobbyStateMachine

AutomaticDedicatedServerJoinNetworkManager.init = function (self, state, lobby)
	self._state = state
	self._lobby = lobby

	Managers.chat:register_chat_rpc_callbacks(self)
end

AutomaticDedicatedServerJoinNetworkManager.update = function (self, dt)
	Network.update(dt, self)
end

AutomaticDedicatedServerJoinNetworkManager.destroy = function (self)
	return
end

AutomaticDedicatedServerJoinNetworkManager.rpc_load_level = function (self, sender, level_key, game_mode_key, game_start_countdown, win_score, time_limit)
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

AutomaticDedicatedServerJoinNetworkManager.rpc_permission_to_enter_game = function (self, sender)
	self._state.parent.permission_to_enter_game = true
end

AutomaticDedicatedServerJoinNetworkManager.drop_in_settings = function (self)
	local drop_in_settings = self._drop_in_settings

	self._drop_in_settings = nil

	return drop_in_settings
end

AutomaticDedicatedServerJoinNetworkManager.rpc_game_server_set = function (self, sender, is_set)
	Managers.lobby:set_game_server_set(is_set)
end
