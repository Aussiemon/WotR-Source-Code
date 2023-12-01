-- chunkname: @scripts/unit_extensions/objectives/assault_unit_damage.lua

AssaultUnitDamage = class(AssaultUnitDamage, ObjectiveUnitDamage)

AssaultUnitDamage.init = function (self, world, unit, input)
	AssaultUnitDamage.super.init(self, world, unit, input)

	self._enable_damage = true
	self._projectile_damage = Unit.get_data(self._unit, "projectile_damage")
end

AssaultUnitDamage._calculate_modified_damage = function (self, damage)
	return self._enable_damage and damage or 0
end

AssaultUnitDamage.enable_damage = function (self, enable_damage)
	self._enable_damage = enable_damage

	local objective_ext = ScriptUnit.extension(self._unit, "objective_system")

	if objective_ext then
		objective_ext:enable_destructible(enable_damage)
	end
end

AssaultUnitDamage.can_receive_damage = function (self, attacker_unit, damage_range_type)
	local player_index = Unit.get_data(attacker_unit, "owner_player_index")
	local player = Managers.player:player(player_index)
	local team_side = player.team.side
	local damage_enabled = self:_damage_enabled(team_side)

	if not damage_enabled or not self._projectile_damage and damage_range_type ~= "melee" then
		return false
	end

	return AssaultUnitDamage.super.can_receive_damage(self, attacker_unit)
end

AssaultUnitDamage._damage_enabled = function (self, team_side)
	if self._dead then
		return false
	end

	local objective_ext = ScriptUnit.extension(self._unit, "objective_system")

	if objective_ext then
		local destructible_active = objective_ext:destructible_active(team_side)

		if not destructible_active then
			return false
		else
			return self._enable_damage
		end
	end
end

AssaultUnitDamage.add_damage = function (self, attacker_player, attacker_unit, damage_type, damage, position, normal, actor, damage_range_type)
	if self._dead then
		return
	end

	if self._projectile_damage or damage_range_type == "melee" then
		AssaultUnitDamage.super.add_damage(self, attacker_player, attacker_unit, damage_type, damage, position, normal, actor, damage_range_type)
	end

	local damage_enabled = self:_damage_enabled(attacker_player.team.side)

	if attacker_player.team.side ~= Unit.get_data(self._unit, "side") and damage_enabled then
		Unit.flow_event(self._unit, "lua_assault_announcement")
	end
end

AssaultUnitDamage.enable_destructible = function (self, team_side, enable)
	if self._dead then
		return
	end

	AssaultUnitDamage.super.enable_destructible(self, team_side, enable)

	local objective_ext = ScriptUnit.extension(self._unit, "objective_system")

	if objective_ext then
		objective_ext:destructible_objective_activated(team_side, enable)
	end
end

AssaultUnitDamage._client_update = function (self, t, dt)
	if self._dead then
		return
	end

	local current_damage = self._damage

	self._damage = GameSession.game_object_field(self._game, self._game_object_id, "damage")

	if self._damage ~= current_damage then
		self:_update_damage_level()
	end
end
