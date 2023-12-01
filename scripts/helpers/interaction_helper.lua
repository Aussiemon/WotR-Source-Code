-- chunkname: @scripts/helpers/interaction_helper.lua

InteractionHelper = InteractionHelper or {}
InteractionHelper.interactions = {
	execute = {},
	revive = {},
	bandage = {},
	trigger = {},
	yield = {}
}

for interaction, config_table in pairs(InteractionHelper.interactions) do
	config_table.request_rpc = "rpc_" .. interaction .. "_request"
	config_table.abort_rpc = "rpc_" .. interaction .. "_abort"
	config_table.complete_rpc = "rpc_" .. interaction .. "_complete"
	config_table.confirm_rpc = "rpc_" .. interaction .. "_confirmed"
	config_table.deny_rpc = "rpc_" .. interaction .. "_denied"
	config_table.confirmed_cb = interaction .. "_interaction_confirmed"
	config_table.denied_cb = interaction .. "_interaction_denied"
end

InteractionHelper.request = function (self, interaction_name, internal, game_object_id, target_id, ...)
	internal["requesting_" .. interaction_name] = true

	Managers.state.network:send_rpc_server(InteractionHelper.interactions[interaction_name].request_rpc, game_object_id, target_id, ...)
end

InteractionHelper.abort = function (self, interaction_name, internal, game_object_id, target_id, ...)
	Managers.state.network:send_rpc_server(InteractionHelper.interactions[interaction_name].abort_rpc, game_object_id, target_id, ...)
end

InteractionHelper.complete = function (self, interaction_name, internal, game_object_id, target_id, ...)
	Managers.state.network:send_rpc_server(InteractionHelper.interactions[interaction_name].complete_rpc, game_object_id, target_id, ...)
end

InteractionHelper.deny_request = function (self, interaction_name, sender, game_object_id)
	RPC[InteractionHelper.interactions[interaction_name].deny_rpc](sender, game_object_id)
end

InteractionHelper.confirm_request = function (self, interaction_name, sender, game_object_id)
	RPC[InteractionHelper.interactions[interaction_name].confirm_rpc](sender, game_object_id)
end

InteractionHelper.confirmed = function (self, interaction_name, internal)
	internal["requesting_" .. interaction_name] = false

	internal[InteractionHelper.interactions[interaction_name].confirmed_cb](internal)
end

InteractionHelper.denied = function (self, interaction_name, internal, game_object_id)
	internal["requesting_" .. interaction_name] = false

	internal[InteractionHelper.interactions[interaction_name].denied_cb](internal)
end

InteractionHelper.can_request = function (self, interaction_name, internal)
	return not internal["requesting_" .. interaction_name]
end
