-- chunkname: @scripts/unit_extensions/generic/generic_unit_interactable.lua

GenericUnitInteractable = class(GenericUnitInteractable)
GenericUnitInteractable.SYSTEM = "objective_system"

GenericUnitInteractable.init = function (self, world, unit, input)
	self._world = world
	self._unit = unit
	self._active = {}
	self._interactor = 0

	local current_level = LevelHelper:current_level(self._world)
	local level_unit_index = Level.unit_index(current_level, unit)

	Unit.set_data(unit, "level_unit_index", level_unit_index)
	Managers.state.event:register(self, "event_start_round", "event_start_round", "event_round_started", "event_round_started")
end

GenericUnitInteractable.event_start_round = function (self)
	for _, side in pairs(Managers.state.team:sides()) do
		self._active[side] = false
	end
end

GenericUnitInteractable.event_round_started = function (self)
	if Managers.lobby.server and Managers.state.network:game() then
		self:_create_game_object()
	end
end

GenericUnitInteractable._create_game_object = function (self)
	local data_table = {
		game_object_created_func = NetworkLookup.game_object_functions.cb_generic_unit_interactable_created,
		object_destroy_func = NetworkLookup.game_object_functions.cb_generic_unit_interactable_destroyed,
		owner_destroy_func = NetworkLookup.game_object_functions.cb_do_nothing,
		level_unit_index = Unit.get_data(self._unit, "level_unit_index"),
		interactor = self._interactor
	}

	for side, active in pairs(self._active) do
		data_table[side .. "_active"] = active
		data_table[side .. "_destructible"] = false
	end

	local callback = callback(self, "cb_game_session_disconnect")

	self._game_object_id = Managers.state.network:create_game_object("generic_unit_interactable", data_table, callback)
	self._game = Managers.state.network:game()
end

GenericUnitInteractable.cb_game_session_disconnect = function (self)
	self._frozen = true

	self:remove_game_object_id()
end

GenericUnitInteractable.flow_cb_activate_interactable = function (self, side)
	self._active[side] = true

	if self._game_object_id then
		GameSession.set_game_object_field(self._game, self._game_object_id, side .. "_active", true)
	end
end

GenericUnitInteractable.flow_cb_deactivate_interactable = function (self, side)
	self._active[side] = false

	if self._game_object_id then
		GameSession.set_game_object_field(self._game, self._game_object_id, side .. "_active", false)
	end
end

GenericUnitInteractable.active = function (self, side)
	return self._active[side]
end

GenericUnitInteractable.interactor = function (self)
	if self._interactor == 0 then
		return nil
	else
		return self._interactor
	end
end

GenericUnitInteractable.can_interact = function (self, player)
	return true
end

GenericUnitInteractable.interaction_complete = function (self, player)
	return
end

GenericUnitInteractable.set_interactor = function (self, player_unit_id)
	if player_unit_id == nil then
		self._interactor = 0
	else
		self._interactor = player_unit_id
	end

	if Managers.state.network:game() then
		GameSession.set_game_object_field(self._game, self._game_object_id, "interactor", self._interactor)
	end
end

GenericUnitInteractable.set_game_object_id = function (self, game_object_id, game)
	self._game_object_id = game_object_id
	self._game = game
end

GenericUnitInteractable.remove_game_object_id = function (self)
	self._game_object_id = nil
	self._game = nil
end

GenericUnitInteractable.set_dead = function (self)
	self._dead = true
end

GenericUnitInteractable.update = function (self, unit, input, dt, context, t)
	if self._dead then
		return
	end

	if Managers.lobby.server then
		self:_server_update(t, dt)
	elseif Managers.lobby.lobby and self._game then
		self:_client_update(t, dt)
	else
		self:_local_update(t, dt)
	end
end

GenericUnitInteractable._server_update = function (self, t, dt)
	return
end

GenericUnitInteractable._client_update = function (self, t, dt)
	for _, side in pairs(Managers.state.team:sides()) do
		local active_before = self._active[side]
		local active = GameSession.game_object_field(self._game, self._game_object_id, side .. "_active")

		if active ~= active_before then
			self:_on_client_active_changed(side, active)
		end

		self._active[side] = active
	end

	self._interactor = GameSession.game_object_field(self._game, self._game_object_id, "interactor")
end

GenericUnitInteractable.level_index = function (self)
	return Unit.get_data(self._unit, "level_unit_index")
end

GenericUnitInteractable.active = function (self, side)
	return self._active[side]
end

GenericUnitInteractable._on_client_active_changed = function (self, team_side, active)
	return
end

GenericUnitInteractable._local_update = function (self, t, dt)
	return
end

GenericUnitInteractable.destroy = function (self)
	return
end
