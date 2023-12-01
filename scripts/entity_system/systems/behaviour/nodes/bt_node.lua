-- chunkname: @scripts/entity_system/systems/behaviour/nodes/bt_node.lua

BTNode = class(BTNode)

BTNode.init = function (self, name, parent, data, input, output)
	self._name = name
	self._parent = parent
	self._data = data
	self._input = input
	self._output = output
end

BTNode.setup = function (self, unit, blackboard, profile)
	return
end

BTNode.run = function (self, unit, blackboard, t, dt)
	ferror("This function should've been overridden in derived class")
end
