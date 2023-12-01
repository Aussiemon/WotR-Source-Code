-- chunkname: @scripts/entity_system/systems/behaviour/nodes/bt_morale_state_update_filter.lua

require("scripts/entity_system/systems/behaviour/nodes/bt_node")

BTMoraleStateUpdateFilter = class(BTMoraleStateUpdateFilter, BTNode)

BTMoraleStateUpdateFilter.init = function (self, ...)
	BTMoraleStateUpdateFilter.super.init(self, ...)
end

BTMoraleStateUpdateFilter.setup = function (self, unit, blackboard, profile)
	self._time = 0

	local player_profile = Unit.get_data(unit, "player_profile")

	self._morale_time = AIProfiles[player_profile].morale.times
	self._period = Math.random_range(self._morale_time.min, self._morale_time.max)

	self._child:setup(unit, blackboard, profile)
end

BTMoraleStateUpdateFilter.run = function (self, unit, blackboard, t, dt)
	self._time = self._time + dt

	if self._time >= self._period then
		self._time = self._time - self._period
		self._period = Math.random_range(self._morale_time.min, self._morale_time.max)

		return self._child:run(unit, blackboard, t, dt)
	end
end

BTMoraleStateUpdateFilter.add_child = function (self, node)
	self._child = node
end
