-- chunkname: @scripts/entity_system/systems/behaviour/nodes/bt_melee_attack_action.lua

require("scripts/entity_system/systems/behaviour/nodes/bt_node")

BTMeleeAttackAction = class(BTMeleeAttackAction, BTNode)

BTMeleeAttackAction.init = function (self, ...)
	BTMeleeAttackAction.super.init(self, ...)
end

BTMeleeAttackAction.setup = function (self, unit, blackboard, profile)
	self._ai_props = profile.properties

	fassert(self._ai_props.charge_time_min, "No 'charge_time_min' defined for AI profile %q", profile.display_name)
	fassert(self._ai_props.charge_time_max, "No 'charge_time_max' defined for AI profile %q", profile.display_name)

	self._weights = self._data.swing_weights or {
		1,
		1,
		1,
		1
	}

	local sum_of_weights = 0

	for _, weight in pairs(self._weights) do
		sum_of_weights = sum_of_weights + weight
	end

	self._sum_of_weights = sum_of_weights
end

BTMeleeAttackAction.run = function (self, unit, blackboard, t, dt)
	local locomotion = ScriptUnit.extension(unit, "locomotion_system")
	local return_value = locomotion.posing and locomotion.swinging and locomotion.attempting_pose and locomotion.pose_ready

	if not locomotion.melee_attack then
		local swing_direction = self:_randomize_swing_direction()
		local charge_time = Math.random_range(self._ai_props.charge_time_min, self._ai_props.charge_time_max)

		locomotion.current_state:safe_action_interrupt("ai_melee_attack")
		locomotion:begin_melee_attack(swing_direction, charge_time)
	end

	return return_value
end

BTMeleeAttackAction._randomize_swing_direction = function (self)
	local rand = math.random(1, self._sum_of_weights)

	for swing_direction, weight in pairs(self._weights) do
		if rand <= weight then
			return swing_direction
		end

		rand = rand - weight
	end
end
