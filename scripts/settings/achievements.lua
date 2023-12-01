-- chunkname: @scripts/settings/achievements.lua

Achievements = class(Achievements)
Achievements.COLLECTION = {
	{
		"placement",
		"=",
		1
	},
	{
		"placement",
		"=",
		2
	},
	{
		"placement",
		"=",
		3
	},
	{
		"all_mounted_prizes",
		"=",
		true
	},
	{
		"all_weapon_prizes",
		"=",
		true
	},
	{
		"all_support_prizes",
		"=",
		true
	},
	{
		"all_prizes",
		"=",
		true
	},
	{
		"rank",
		">=",
		1
	},
	{
		"rank",
		">=",
		7
	},
	{
		"rank",
		">=",
		13
	},
	{
		"rank",
		">=",
		20
	},
	{
		"rank",
		">=",
		25
	},
	[14] = {
		"rank",
		">=",
		30
	},
	[15] = {
		"rank",
		">=",
		40
	},
	[16] = {
		"rank",
		">=",
		50
	},
	[17] = {
		"rank",
		">=",
		60
	},
	[18] = {
		"experience_round_final",
		">=",
		10000
	},
	[19] = {
		"kill_streak",
		">=",
		10
	},
	[20] = {
		"longshots",
		">=",
		1
	},
	[21] = {
		"headshots_with_crossbow",
		">=",
		2001
	},
	[22] = {
		"teabags",
		">=",
		1
	}
}

Achievements.init = function (self, stats_collection)
	self._stats = stats_collection
end

Achievements.register_player = function (self, player)
	local network_id = player:network_id()

	for achievement_id, props in pairs(self.COLLECTION) do
		if not self._stats:get(network_id, "achievement_" .. achievement_id) then
			local stat_name, condition, value = unpack(props)
			local callback = callback(self, "_cb_award_achievement", player, achievement_id)

			self._stats:register_callback(network_id, stat_name, condition, value, callback)
		end
	end
end

Achievements._cb_award_achievement = function (self, player, achievement_id)
	if Managers.state.network:game() and Managers.state.team:stats_requirement_fulfilled() then
		printf("%q got awarded achievement %d", player:network_id(), achievement_id)
		self._stats:set(player:network_id(), "achievement_" .. achievement_id, true)
		RPC.rpc_award_achievement(player:network_id(), player.game_object_id, achievement_id)
	end
end
