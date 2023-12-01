-- chunkname: @scripts/managers/stats/stats_collector_client.lua

StatsCollectorClient = class(StatsCollectorClient)

StatsCollectorClient.weapon_missed = function (self, player, gear_name)
	if Managers.state.network:game() then
		Managers.state.network:send_rpc_server("rpc_stat_weapon_missed", player.game_object_id, NetworkLookup.gear_names[gear_name])
	end
end

StatsCollectorClient.player_revived = function (self, revivee, reviver)
	return
end
