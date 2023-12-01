-- chunkname: @scripts/unit_extensions/horse/states/horse_onground_mounted_ai.lua

HorseOngroundMountedAi = class(HorseOngroundMountedAi, HorseOnground)

local ROTATION_MAX_SPEED = 2
local settings = HorseUnitMovementSettings.gaits

HorseOngroundMountedAi.init = function (self, unit, locomotion)
	HorseOngroundMountedAi.super.init(self, unit, locomotion)

	self._rotation_speed_anim_var = Unit.animation_find_variable(unit, "horse_rotation_speed")
	self._anim_driven_rotation_speed_var = Unit.animation_find_variable(unit, "horse_idle_rotation_speed")
end

HorseOngroundMountedAi.enter = function (self, old_state)
	HorseOngroundMountedAi.super.enter(self, old_state)
end

HorseOngroundMountedAi.update = function (self, unit, internal, controller, dt, context, t)
	HorseOngroundMountedAi.super.super.update(self, unit, internal, controller, dt, context, t)

	local rider = Unit.get_data(unit, "user_unit")
	local ai_base = ScriptUnit.extension(rider, "ai_system")
	local steering_force = ai_base:steering():force()

	self:_update_speed(unit, steering_force, dt)
	self:ground_raycast(unit, self._internal)
	self:update_rotation(dt)

	if internal.charging then
		self:update_charge(dt, t)
	else
		self:_match_gait()
	end

	self:set_movement_speed_anim_var(self._internal.speed)
	self:update_movement(dt)
	self:update_transition(dt, t)
end

HorseOngroundMountedAi._update_speed = function (self, unit, steering_force, dt)
	local current_rot = Unit.world_rotation(unit, 0)
	local current_fwd = Quaternion.forward(current_rot)
	local velocity = self._internal.speed * current_fwd
	local acceleration = steering_force
	local wanted_velocity = velocity + acceleration
	local wanted_speed = Vector3.length(wanted_velocity)

	if wanted_speed > self._internal.speed and self._internal.speed < HorseUnitMovementSettings.gaits.gallop.speed_max then
		self._internal.speed = HorseUnitMovementSettings.acceleration_function(self._internal.speed, dt)
	elseif wanted_speed < self._internal.speed then
		self._internal.speed = HorseUnitMovementSettings.brake_function(self._internal.speed, dt)
	end

	self:_update_turn_speed(unit, wanted_velocity, dt)
end

HorseOngroundMountedAi._update_turn_speed = function (self, unit, wanted_velocity, dt)
	local current_rot = Unit.world_rotation(unit, 0)
	local current_fwd = Quaternion.forward(current_rot)
	local turn = Vector3.dot(current_fwd, Vector3.normalize(wanted_velocity))

	turn = math.clamp(turn, 0, 1)

	local turn_direction = Vector3.cross(wanted_velocity, current_fwd).z
	local turn_amount = math.sign(turn_direction) * math.acos(turn)

	self._internal.rot_speed = ROTATION_MAX_SPEED * turn_amount / (math.pi / 2)
end

HorseOngroundMountedAi._match_gait = function (self)
	local wanted_gait_name, wanted_gait
	local current_gait = HorseUnitMovementSettings.gaits[HorseUnitMovementSettings.gait_order[self._internal.gait_index]]

	for i = #HorseUnitMovementSettings.gait_order, 1, -1 do
		local gait_name, gait = HorseUnitMovementSettings.gait_order[i]
		local gait = HorseUnitMovementSettings.gaits[gait_name]

		if self._internal.speed >= gait.speed_min then
			wanted_gait_name, wanted_gait = gait_name, gait

			break
		end
	end

	if wanted_gait ~= current_gait then
		local wanted_gait_index = HorseUnitMovementSettings.gait_lookup[wanted_gait_name]

		self._internal.gait_index = wanted_gait_index

		self:_play_gait_animation(wanted_gait, self._internal)
	end
end

HorseOngroundMountedAi.exit = function (self, new_state)
	HorseOngroundMountedAi.super.exit(self, new_state)
end
