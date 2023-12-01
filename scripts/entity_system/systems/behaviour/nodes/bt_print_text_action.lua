-- chunkname: @scripts/entity_system/systems/behaviour/nodes/bt_print_text_action.lua

require("scripts/entity_system/systems/behaviour/nodes/bt_node")

BTPrintTextAction = class(BTPrintTextAction, BTNode)

BTPrintTextAction.init = function (self, ...)
	BTPrintTextAction.super.init(self, ...)
end

BTPrintTextAction.run = function (self, unit, blackboard, t, dt)
	print(self._data.text)
end
