-- chunkname: @scripts/unit_extensions/weapons/weapon_ranged_base.lua

require("scripts/helpers/weapon_helper")

WeaponRangedBase = class(WeaponRangedBase)

WeaponRangedBase.init = function (self, world, unit, user_unit, player, id, ai_gear, attachments, properties, attachment_multipliers)
	self._world = world
	self._unit = unit
	self._user_unit = user_unit
	self._player = player
	self._game_object_id = id
	self._timpani_world = World.timpani_world(world)
	self._settings = Unit.get_data(unit, "settings")
	self._gear_name = Unit.get_data(unit, "gear_name")
	self._projectile_name = attachments and attachments.projectile_head and attachments.projectile_head[1] or "standard"
	self._projectile_settings = WeaponHelper:attachment_settings(self._gear_name, "projectile_head", self._projectile_name)
	self._reload_time = nil
	self._finish_reload_anim_name = nil
	self._fire_anim_name = nil
	self._aim_anim_name = nil
	self._aim_anim_var_name = nil
	self._unaim_anim_name = nil
	self._loaded = true
	self._reloading = false
	self._wield_finished_anim_name = nil
	self._firing_timer = nil
	self._firing_event = false
	self._firing = false
	self._needs_unaiming = false
end

WeaponRangedBase.projectile_name = function (self)
	return self._projectile_name
end

WeaponRangedBase.loaded = function (self)
	return self._loaded
end

WeaponRangedBase.set_loaded = function (self, loaded)
	self._loaded = loaded
end

WeaponRangedBase.reloading = function (self)
	return self._reloading
end

WeaponRangedBase.firing_event = function (self)
	return self._firing_event
end

WeaponRangedBase.fire_anim_name = function (self)
	return self._fire_anim_name
end

WeaponRangedBase.wield_finished_anim_name = function (self)
	return self._wield_finished_anim_name
end

WeaponRangedBase.update = function (self, dt, t)
	return
end

WeaponRangedBase.start_reload = function (self, reload_time, reload_blackboard)
	self._reload_time = reload_time
	self._reload_blackboard = reload_blackboard
	self._reloading = true
end

WeaponRangedBase.update_reload = function (self, dt, t, fire_input)
	return
end

WeaponRangedBase.finish_reload = function (self, reload_successful)
	self._reloading = false

	return self._finish_reload_anim_name
end

WeaponRangedBase.uses_ammo = function (self)
	return false
end

WeaponRangedBase.needs_unaiming = function (self)
	return self._needs_unaiming
end

WeaponRangedBase.set_needs_unaiming = function (self, needs_unaiming)
	self._needs_unaiming = needs_unaiming
end

WeaponRangedBase.can_wield = function (self)
	return true
end

WeaponRangedBase.can_reload = function (self)
	return true
end

WeaponRangedBase.can_aim = function (self)
	return true
end

WeaponRangedBase.can_steady = function (self)
	return false
end

WeaponRangedBase.can_fire = function (self)
	return self._loaded
end

WeaponRangedBase.category = function (self)
	return self._weapon_category
end

WeaponRangedBase.aim = function (self)
	return self._aim_anim_name, self._aim_anim_var_name
end

WeaponRangedBase.unaim = function (self)
	return self._unaim_anim_name
end

WeaponRangedBase.ready_projectile = function (self, slot_name)
	return
end

WeaponRangedBase.release_projectile = function (self, slot_name, draw_time)
	self._loaded = false
end

WeaponRangedBase.set_wielded = function (self, wielded)
	return
end

WeaponRangedBase.hot_join_synch = function (self, sender, player, player_object_id, slot_name)
	return
end

WeaponRangedBase.enter_ghost_mode = function (self)
	self._ghost_mode = true
end

WeaponRangedBase.exit_ghost_mode = function (self)
	self._ghost_mode = false
end

WeaponRangedBase.destroy = function (self)
	return
end
