-- chunkname: @scripts/unit_extensions/human/ai_player_unit/states/ai_mounted.lua

require("scripts/unit_extensions/human/base/states/human_mounted")

AIMounted = class(AIMounted, HumanMounted)

AIMounted.enter = function (self, old_state)
	AIMounted.super.enter(self, old_state)

	self._internal.posing = false
	self._internal.swinging = false

	local mount = self._internal.mounted_unit
	local mount_node = Unit.node(mount, "CharacterAttach")

	World.link_unit(self._internal.world, self._unit, mount, mount_node)
	self:anim_event("mount_horse")
	Managers.player:assign_unit_ownership(mount, Unit.get_data(self._unit, "owner_player_index"))
	Unit.set_data(mount, "user_unit", self._unit)

	self._internal.mounting = true
end

AIMounted.anim_cb_mounting_complete = function (self)
	self._internal.mounting = false

	self:anim_event("horse_mounted")
end

AIMounted.update = function (self, dt, t)
	self:_update_velocity(dt, t)
	self:_update_swing(dt, t)
	self:_update_transition(dt, t)

	self._transition = nil
end

AIMounted._update_velocity = function (self, dt, t)
	local mount_velocity = ScriptUnit.extension(self._internal.mounted_unit, "locomotion_system"):get_velocity()

	self._internal:set_velocity(mount_velocity)
	self._internal:_update_look(t, dt, mount_velocity)
end

AIMounted._update_swing = function (self, dt, t)
	local internal = self._internal
	local can_couch, couch_slot = self:can_couch(t)

	if can_couch and not internal.couching then
		self:_begin_couch(t, couch_slot)

		return
	elseif can_couch then
		self:_update_couch(dt, t)

		return
	elseif internal.couching then
		self:end_couch(t)
	end
end

AIMounted._begin_couch = function (self, t, couch_slot)
	local internal = self._internal
	local inventory = internal:inventory()

	internal.couching = true

	inventory:start_couch(couch_slot)

	self._couch_slot = couch_slot

	local settings = inventory:gear_couch_settings(couch_slot)

	self:anim_event_with_variable_float("lance_couch", "lance_couch_time", settings.couch_time)
end

AIMounted._update_couch = function (self, dt, t)
	local internal = self._internal
	local target = internal.jousting_target
	local aim_target

	if Unit.alive(target) then
		local target_locomotion = ScriptUnit.extension(target, "locomotion_system")

		if not target_locomotion.knocked_down and target_locomotion.mounted_unit then
			aim_target = Unit.world_position(target, Unit.node(target, "Neck")) + internal.aim_offset:unbox()

			Unit.animation_set_constraint_target(self._unit, self._aim_constraint_anim_var, aim_target)
		end
	end
end

AIMounted.end_couch = function (self, t)
	local internal = self._internal
	local inventory = internal:inventory()

	internal.couching = false

	local couch_slot = self._couch_slot

	inventory:end_couch(couch_slot)

	local settings = inventory:gear_couch_settings(couch_slot)

	self._couch_slot = nil
	internal.jousting_target = nil
	internal.aim_offset = nil

	self:anim_event_with_variable_float("lance_uncouch", "lance_uncouch_time", settings.uncouch_time)
end

AIMounted.post_update = function (self, dt, t)
	return
end

AIMounted._update_transition = function (self, dt, t)
	if self._transition then
		self:change_state(self._transition)

		return true
	end
end

AIMounted.anim_cb_dismounting_complete = function (self)
	self._transition = "onground"
end

AIMounted.exit = function (self, new_state)
	AIMounted.super.exit(self, new_state)
	World.unlink_unit(self._internal.world, self._unit)

	if self._internal.couching then
		self:end_couch(Managers.time:time("game"))
	end

	local mount = self._internal.mounted_unit
	local mount_rot = Unit.world_rotation(mount, 0)
	local dismount_position = Unit.world_position(mount, 0) + Vector3.up() - Quaternion.right(mount_rot)
	local mover = Unit.mover(self._unit)

	Mover.set_position(mover, dismount_position)
	Mover.move(mover, Vector3(0, 0, -1.1), World.delta_time(self._internal.world))
	self:set_local_position(Mover.position(mover))
	self:anim_event("horse_dismounted")

	local mount_owner = Managers.player:owner(mount)

	if mount_owner and mount_owner.index == Unit.get_data(self._unit, "owner_player_index") then
		Managers.player:relinquish_unit_ownership(mount)
	end

	if self._unit == Unit.get_data(mount, "user_unit") then
		Unit.set_data(mount, "user_unit", nil)
	end

	self._internal.mounted_unit = nil
	self._internal.dismounting = false
	self._internal.mounting = false
end
