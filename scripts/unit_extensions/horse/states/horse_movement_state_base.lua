-- chunkname: @scripts/unit_extensions/horse/states/horse_movement_state_base.lua

HorseMovementStateBase = class(HorseMovementStateBase)
ROTATION_LERP_FACTOR = 10
ROTATION_ANIM_LERP_FACTOR = 5

HorseMovementStateBase.init = function (self, unit, internal)
	self._unit = unit
	self._internal = internal
	self._move_speed_anim_var = Unit.animation_find_variable(unit, "horse_move_speed")
	self._rotation_speed_anim_var = Unit.animation_find_variable(unit, "horse_rotation_speed")
	self._anim_driven_rotation_speed_var = Unit.animation_find_variable(unit, "horse_idle_rotation_speed")
end

HorseMovementStateBase.update = function (self, dt)
	return
end

HorseMovementStateBase.post_update = function (self, dt)
	local internal = self._internal

	if internal.id and internal.game and internal.current_state_name ~= "husk" then
		GameSession.set_game_object_field(internal.game, internal.id, "velocity", internal.velocity:unbox())
	end
end

HorseMovementStateBase.enter = function (self, old_state)
	Unit.set_data(self._unit, "current_state_name", self._internal.current_state_name)
end

HorseMovementStateBase.exit = function (self, new_state)
	return
end

HorseMovementStateBase.destroy = function (self)
	return
end

HorseMovementStateBase.change_state = function (self, new_state)
	if script_data.anim_debug then
		print("ENTER " .. new_state)
	end

	local internal = self._internal

	self:exit(new_state)

	internal.current_state = internal._states[new_state]

	local old_state = internal.current_state_name

	internal.current_state_name = new_state

	internal.current_state:enter(old_state)
end

HorseMovementStateBase._enter_cruise_control = function (self)
	local internal = self._internal

	internal.cruise_control = true
	internal.cruise_control_gear = HorseUnitMovementSettings.cruise_control.start_gear
	internal.acceleration = 0
end

HorseMovementStateBase._exit_cruise_control = function (self)
	self._internal.cruise_control = false
end

HorseMovementStateBase._update_cruise_control_gear = function (self, dt, t, gear_change)
	local internal = self._internal

	internal.cruise_control_gear = math.clamp(internal.cruise_control_gear + gear_change, 1, #HorseUnitMovementSettings.cruise_control.gears)
end

HorseMovementStateBase.update_cruise_control = function (self, dt, t)
	local internal = self._internal
	local controller = self._controller
	local cruise_control_gear_up = controller and self._controller:get("mount_cruise_control_gear_up")
	local cruise_control_gear_down = controller and self._controller:get("mount_cruise_control_gear_down")
	local move_pressed = controller and (self._controller:get("mount_move_forward_pressed") or self._controller:get("mount_move_back_pressed"))

	if not internal.cruise_control and (cruise_control_gear_up or cruise_control_gear_down) then
		self:_enter_cruise_control()
	elseif internal.cruise_control and move_pressed then
		self:_exit_cruise_control()
	end

	if internal.cruise_control then
		self:_update_cruise_control_gear(dt, t, (cruise_control_gear_up and 1 or 0) - (cruise_control_gear_down and 1 or 0))
	end
end

HorseMovementStateBase.set_local_rotation = function (self, new_rot)
	Unit.set_local_rotation(self._unit, 0, new_rot)

	local internal = self._internal

	if internal.game and internal.id then
		GameSession.set_game_object_field(internal.game, internal.id, "rotation", new_rot)
	end
end

HorseMovementStateBase.set_local_position = function (self, new_pos)
	Unit.set_local_position(self._unit, 0, new_pos)

	local internal = self._internal

	if internal.game and internal.id and Vector3.length(new_pos) < 1000 then
		GameSession.set_game_object_field(internal.game, internal.id, "position", new_pos)
	end
end

HorseMovementStateBase.set_movement_speed_anim_var = function (self, speed)
	local unit = self._unit

	Unit.animation_set_variable(unit, self._move_speed_anim_var, speed)

	local rider = Unit.get_data(unit, "user_unit")

	if rider then
		Unit.animation_set_variable(rider, Unit.animation_find_variable(rider, "horse_move_speed"), speed)
	end

	if self._internal.game and self._internal.id then
		GameSession.set_game_object_field(self._internal.game, self._internal.id, "move_speed", speed)
	end
end

HorseMovementStateBase.anim_event = function (self, event, force_local)
	local internal = self._internal
	local unit = self._unit

	if not force_local and internal.game and internal.id then
		local event_id = NetworkLookup.anims[event]

		assert(event_id, "[HorseMovementStateBase:anim_event()] Network synked event " .. tostring(event) .. " does not exist in network_lookup.lua.")

		if Managers.lobby.server then
			Managers.state.network:send_rpc_clients("rpc_anim_event", event_id, internal.id)
		else
			Managers.state.network:send_rpc_server("rpc_anim_event", event_id, internal.id)
		end
	end

	Unit.animation_event(unit, event)

	local rider = Unit.get_data(unit, "user_unit")

	if rider then
		Unit.animation_event(rider, event)
	end
end

HorseMovementStateBase.can_charge = function (self)
	return false
end
