﻿-- chunkname: @scripts/settings/server_browser_score.lua

ServerBrowserScore = class(ServerBrowserScore)

ServerBrowserScore.init = function (self, stats_collection)
	self._stats = stats_collection
end

ServerBrowserScore.register_player = function (self, player)
	local network_id = player:network_id()
	local callback = callback(self, "_cb_score_increased", player)

	self._stats:register_callback(network_id, "experience_round", "<", math.huge, callback)

	local score = self._stats:get(player:network_id(), "experience_round")

	Managers.lobby:set_score(player:network_id(), score)
end

ServerBrowserScore._cb_score_increased = function (self, player)
	local score = self._stats:get(player:network_id(), "experience_round")

	Managers.lobby:set_score(player:network_id(), score)
end
