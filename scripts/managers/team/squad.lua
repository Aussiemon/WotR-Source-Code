-- chunkname: @scripts/managers/team/squad.lua

Squad = class(Squad)

Squad.init = function (self, index, max_size)
	self._index = index
	self._max_size = max_size
	self._members = {}
	self._corporal = nil
end

Squad.request_to_join = function (self, player)
	if Managers.state.network:game() then
		Managers.state.network:send_rpc_server("rpc_request_to_join_squad", player.game_object_id, self._index)
	end
end

Squad.request_to_leave = function (self, player)
	if Managers.state.network:game() then
		Managers.state.network:send_rpc_server("rpc_request_to_leave_squad", player.game_object_id, self._index)
	end
end

Squad.can_join = function (self, player)
	return self._members[player] == nil and self:num_members() < self._max_size
end

Squad.can_leave = function (self, player)
	return self._members[player] ~= nil
end

Squad.add_member = function (self, player)
	self._members[player] = true
	player.squad_index = self._index

	if Managers.lobby.server then
		Managers.state.network:send_rpc_clients("rpc_add_player_to_squad", player.game_object_id, self._index)

		if table.size(self._members) == 1 then
			self:set_corporal(player)
		end
	end

	Managers.state.event:trigger("player_joined_squad", player, self._index)
end

Squad.remove_member = function (self, player)
	self._members[player] = nil
	player.squad_index = nil

	if Managers.lobby.server then
		Managers.state.network:send_rpc_clients("rpc_remove_player_from_squad", player.game_object_id, self._index)
	end

	Managers.state.event:trigger("player_left_squad", player, self._index)

	if Managers.lobby.server and player.is_corporal then
		self:pick_new_corporal()
	end

	if player.is_corporal then
		Managers.state.event:trigger("player_no_longer_corporal", player)
	end

	player.is_corporal = false
end

Squad.pick_new_corporal = function (self)
	local new_corporal = next(self._members)

	if new_corporal then
		self:set_corporal(new_corporal)
	else
		self._corporal = nil
	end
end

Squad.set_corporal = function (self, player)
	self._corporal = player
	player.is_corporal = true

	if Managers.lobby.server then
		Managers.state.network:send_rpc_clients("rpc_set_squad_corporal", player.game_object_id, self._index)
	end

	Managers.state.event:trigger("player_became_corporal", player)
end

Squad.index = function (self)
	return self._index
end

Squad.corporal = function (self)
	return self._corporal
end

Squad.members = function (self)
	return self._members
end

Squad.num_members = function (self)
	return table.size(self._members)
end

Squad.set_max_size = function (self, max_size)
	self._max_size = max_size
end

Squad.max_size = function (self)
	return self._max_size
end

Squad.synch = function (self, new_player)
	for member, _ in pairs(self._members) do
		RPC.rpc_add_player_to_squad(new_player, member.game_object_id, self._index)
	end

	if self._corporal then
		RPC.rpc_set_squad_corporal(new_player, self._corporal.game_object_id, self._index)
	end

	RPC.rpc_set_max_squad_size(new_player, self._max_size)
end
