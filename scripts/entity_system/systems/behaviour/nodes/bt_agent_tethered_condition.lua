-- chunkname: @scripts/entity_system/systems/behaviour/nodes/bt_agent_tethered_condition.lua

require("scripts/entity_system/systems/behaviour/nodes/bt_condition")

BTAgentTetheredCondition = class(BTAgentTetheredCondition, BTCondition)

BTAgentTetheredCondition.init = function (self, ...)
	BTAgentTetheredCondition.super.init(self, ...)
end

BTAgentTetheredCondition.setup = function (self, unit, blackboard, profile)
	BTAgentTetheredCondition.super.setup(self, unit, blackboard, profile)

	self._ai_props = profile.properties
end

BTAgentTetheredCondition.accept = function (self, unit, blackboard, t, dt)
	local locomotion = ScriptUnit.extension(unit, "locomotion_system")

	return self._ai_props.tethered and not locomotion.in_movement_area and locomotion.tether_timer <= 0
end
