-- chunkname: @scripts/entity_system/systems/behaviour/nodes/bt_nil_action.lua

require("scripts/entity_system/systems/behaviour/nodes/bt_node")

BTNilAction = class(BTNilAction, BTNode)

BTNilAction.init = function (self, ...)
	BTNilAction.super.init(self, ...)
end

BTNilAction.run = function (self, unit, blackboard, t, dt)
	return
end
