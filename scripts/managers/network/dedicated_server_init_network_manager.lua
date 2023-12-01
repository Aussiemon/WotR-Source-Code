-- chunkname: @scripts/managers/network/dedicated_server_init_network_manager.lua

require("scripts/network_lookup/network_lookup")

DedicatedServerInitNetworkManager = class(DedicatedServerInitNetworkManager)

local Lobby = LanLobbyStateMachine

DedicatedServerInitNetworkManager.init = function (self, state, lobby)
	self._state = state
	self._lobby = lobby

	local meta = getmetatable(RPC)

	meta._old__index = meta.__index

	meta.__index = function (t, k)
		local function func(peer, ...)
			if peer == Network.peer_id() then
				local network_manager = Managers.state.network

				network_manager[k](network_manager, peer, ...)
			else
				local meta = getmetatable(t)

				meta._old__index(t, k)(peer, ...)
			end
		end

		return func
	end

	setmetatable(RPC, meta)

	if self._lobby then
		Network.set_pong_timeout(GameSettingsDevelopment.network_timeout)
	end

	Managers.chat:register_chat_rpc_callbacks(self)
end

DedicatedServerInitNetworkManager.update = function (self, dt)
	Network.update(dt, self)
end

DedicatedServerInitNetworkManager.destroy = function (self)
	return
end
