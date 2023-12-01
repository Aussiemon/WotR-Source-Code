-- chunkname: @scripts/managers/group/formations/skirmish_formation.lua

SkirmishFormation = class(SkirmishFormation)

SkirmishFormation.init = function (self)
	self._num_slots = 0
	self._offsets = {}
end

SkirmishFormation.request_slot = function (self)
	return
end

SkirmishFormation.relinquish_slot = function (self, slot)
	return
end
