-- chunkname: @scripts/entity_system/systems/behaviour/nodes/bt_update_filter.lua

require("scripts/entity_system/systems/behaviour/nodes/bt_node")

BTUpdateFilter = class(BTUpdateFilter, BTNode)

BTUpdateFilter.init = function (self, ...)
	BTUpdateFilter.super.init(self, ...)
end

BTUpdateFilter.setup = function (self, unit, blackboard, profile)
	self._time = 0
	self._period = Math.random_range(self._data.min, self._data.max)

	self._child:setup(unit, blackboard, profile)
end

BTUpdateFilter.run = function (self, unit, blackboard, t, dt)
	self._time = self._time + dt

	if self._time >= self._period then
		self._time = self._time - self._period

		return self._child:run(unit, blackboard, t, dt)
	end
end

BTUpdateFilter.add_child = function (self, node)
	self._child = node
end
