-- chunkname: @scripts/entity_system/systems/behaviour/nodes/bt_crouch_action.lua

require("scripts/entity_system/systems/behaviour/nodes/bt_node")

BTCrouchAction = class(BTCrouchAction, BTNode)

BTCrouchAction.init = function (self, ...)
	BTCrouchAction.super.init(self, ...)
end

BTCrouchAction.run = function (self, unit, blackboard, t, dt)
	local locomotion = ScriptUnit.extension(unit, "locomotion_system")

	if not locomotion.start_or_stop_crouch then
		locomotion:crouch()
	end

	return locomotion.crouching
end
