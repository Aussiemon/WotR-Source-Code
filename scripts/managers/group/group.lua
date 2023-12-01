-- chunkname: @scripts/managers/group/group.lua

require("scripts/managers/group/group_locomotion")
require("scripts/managers/group/group_navigation")
require("scripts/managers/group/group_commands")

Group = class(Group)

Group.init = function (self, world, formation, pos, rot)
	self._world = world
	self._formation = formation
	self._units = {}
	self._locomotion = GroupLocomotion:new(self, self._units, pos, rot)
	self._navigation = GroupNavigation:new(world, self._locomotion)

	Managers.state.event:register(self, "ai_unit_died", "cb_unit_died")
end

Group.world = function (self)
	return self._world
end

Group.cb_unit_died = function (self, unit)
	self:remove_unit(unit)
	Managers.state.event:trigger("unit_in_group_died", unit)
end

Group.add_unit = function (self, unit)
	local slot = self._formation:request_slot()

	self._units[unit] = slot

	self._locomotion:unit_added(unit)
end

Group.spawn_in = function (self, world, unit_name)
	local slot = self._formation:request_slot()
	local offset = self._formation:offset(slot)
	local pos, rot = self._locomotion:position_rotation_from_offset(offset)
	local unit = World.spawn_unit(world, unit_name, pos, rot)

	self._units[unit] = slot

	return unit
end

Group.remove_unit = function (self, unit)
	local slot = self._units[unit]

	if slot then
		self._formation:relinquish_slot(slot)

		self._units[unit] = nil

		self._locomotion:unit_removed()
	end
end

Group.num_members = function (self)
	return table.size(self._units)
end

Group.update = function (self, dt, t)
	self._locomotion:update(dt, t)
end

Group.formation = function (self)
	return self._formation
end

Group.locomotion = function (self)
	return self._locomotion
end

Group.navigation = function (self)
	return self._navigation
end
