-- chunkname: @scripts/unit_extensions/generic/generic_unit_damage.lua

GenericUnitDamage = class(GenericUnitDamage)
GenericUnitDamage.SYSTEM = "damage_system"

GenericUnitDamage.init = function (self, world, unit, input)
	self._world = world
	self._unit = unit
	self._damage = 0
	self._dead = false

	local health = Unit.get_data(unit, "health")

	if health == -1 then
		Unit.set_data(unit, "health", nil)

		self._health = math.huge
	else
		self._health = health
	end
end

GenericUnitDamage.network_recieve_add_damage = function (self, attacker_player, attacker_unit, damage_type, damage, position, normal, damage_range_type)
	self:add_damage(attacker_player, attacker_unit, damage_type, damage, position, normal, nil, damage_range_type)
end

GenericUnitDamage.network_recieve_add_damage_over_time = function (self, ...)
	self:add_damage_over_time(...)
end

GenericUnitDamage.reset_damage = function (self)
	self._damage = 0
end

GenericUnitDamage.add_damage_over_time = function (self, ...)
	return
end

GenericUnitDamage.add_damage = function (self, attacker_player, attacker_unit, damage_type, damage, position, normal, actor, damage_range_type)
	self._damage = self._damage + damage

	if not self:is_dead() and self._damage >= self._health then
		self:die(damage)
	end

	if script_data.damage_debug then
		print("[GenericUnitDamage] add_damage " .. self._damage .. "/" .. self._health)
	end
end

GenericUnitDamage.die = function (self, damage)
	self._dead = true

	if Unit.has_data(self._unit, "gear_name") then
		self:_gear_dead(damage)
	else
		self:_prop_dead(damage)
	end
end

GenericUnitDamage._gear_dead = function (self, damage)
	local unit = self._unit
	local network_manager = Managers.state.network

	if not Managers.lobby.lobby then
		local user_unit = Unit.get_data(unit, "user_unit")
		local locomotion = ScriptUnit.extension(user_unit, "locomotion_system")

		locomotion:gear_dead(unit)
	elseif network_manager:game() then
		local object_id = network_manager:game_object_id(unit)
		local owner = network_manager:game_object_owner(object_id)

		if owner == Network.peer_id() then
			local user_unit = Unit.get_data(unit, "user_unit")
			local locomotion = ScriptUnit.extension(user_unit, "locomotion_system")

			locomotion:gear_dead(unit)
		else
			RPC.rpc_gear_destroyed(owner, object_id)
		end
	end
end

GenericUnitDamage._prop_dead = function (self, damage)
	local unit = self._unit

	Unit.set_flow_variable(unit, "damage", damage)
	Unit.flow_event(unit, "lua_dead")
end

GenericUnitDamage.is_dead = function (self)
	return self._dead
end

GenericUnitDamage.is_alive = function (self)
	return not self._dead
end

GenericUnitDamage.destroy = function (self)
	WeaponHelper:remove_projectiles(self._unit)
end
