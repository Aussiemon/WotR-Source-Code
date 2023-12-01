-- chunkname: @scripts/unit_extensions/weapons/weapon_lance.lua

require("scripts/unit_extensions/weapons/weapon_one_handed")

WeaponLance = class(WeaponLance, WeaponOneHanded)

WeaponLance.init = function (self, world, unit, user_unit, player, id, ai_gear, attachments, properties, attachment_multipliers)
	WeaponLance.super.init(self, world, unit, user_unit, player, id, ai_gear, attachments, properties, attachment_multipliers)

	self._couching = false
	self._weapon_category = "lance"
end

WeaponLance.can_wield = function (self, player_state_name)
	return player_state_name == "mounted" and WeaponLance.super.can_wield(self, player_state_name)
end

WeaponLance.set_wielded = function (self, wielded)
	if not wielded and self._couching then
		self:end_couch()
	end
end

WeaponLance.update = function (self, dt, t, ...)
	if self._couching then
		self._current_attack.attack_time = self._current_attack.attack_time + dt
	end

	WeaponLance.super.update(self, dt, t, ...)
end

WeaponLance.start_couch = function (self, abort_attack_func)
	self._couching = true

	assert(not self._attacking, "Can't attack and couch at the same time.")

	self._current_attack = {
		last_attack_time = 0,
		attack_time = 0,
		attack_name = "couch",
		attack_duration = self._settings.attacks.couch.couch_time,
		abort_func = abort_attack_func,
		hits = {}
	}

	if self._settings.sweep_collision then
		self:_activate_sweep_collision()
	else
		self:_enable_hit_collision()
	end
end

WeaponLance.end_couch = function (self)
	self._couching = false

	local hit_unit_type = self._hit_unit_type

	self._current_attack = nil

	if self._settings.sweep_collision then
		self:_deactivate_sweep_collision()
	else
		self:_disable_hit_collision()
	end

	return hit_unit_type
end

WeaponLance.non_damage_hit_cb = function (self, hit_unit, actor, normal, position, self_actor)
	WeaponLance.super.non_damage_hit_cb(self, hit_unit, actor, normal, position, self_actor, self._couching)

	if self._ai_gear then
		self:_abort_ai_attack()
	end
end

WeaponLance.hit_cb = function (self, hit_unit, actor, normal, position, self_actor)
	WeaponLance.super.hit_cb(self, hit_unit, actor, normal, position, self_actor, self._couching)

	if self._ai_gear then
		self:_abort_ai_attack()
	end
end

WeaponLance._target_type = function (self, hit_unit, current_attack)
	local target_type
	local abort = true

	table.dump(current_attack.hits)

	target_type = not current_attack.hits[hit_unit].penetrated and "not_penetrated" or Unit.get_data(hit_unit, "soft_target") and "soft" or "hard"

	self:_abort_attack(target_type)

	return target_type, abort
end

WeaponLance._damage_type = function (self, attack)
	return self._attachments.lance_tip[1] == "coronel" and "blunt" or "piercing"
end

WeaponLance._abort_ai_attack = function (self)
	local user_unit_locomotion = ScriptUnit.extension(self._user_unit, "locomotion_system")

	if user_unit_locomotion.couching and user_unit_locomotion.mounted_unit then
		local mounted_unit_locomotion = ScriptUnit.extension(user_unit_locomotion.mounted_unit, "locomotion_system")

		mounted_unit_locomotion.current_state:end_charge(Managers.time:time("game"))
	end
end
