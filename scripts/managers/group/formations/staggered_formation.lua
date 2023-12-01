-- chunkname: @scripts/managers/group/formations/staggered_formation.lua

StaggeredFormation = class(StaggeredFormation)

local settings = AISettings.group.formation.staggered

StaggeredFormation.init = function (self, rank_distance, file_distance)
	self._rank_distance = rank_distance or settings.default_rank_distance
	self._file_distance = file_distance or settings.default_file_distance
	self._offsets = {}
end

StaggeredFormation.create_from_string = function (definition)
	local args = {}

	for arg in definition:gmatch("(%d+)") do
		args[#args + 1] = arg
	end

	return StaggeredFormation:new(unpack(args))
end

StaggeredFormation.set_rank_distance = function (self, distance)
	self._rank_distance = distance
end

StaggeredFormation.set_file_distance = function (self, distance)
	self._file_distance = distance
end

StaggeredFormation.request_slot = function (self)
	local slot = #self._offsets + 1

	self._offsets[slot] = Vector3Box()

	self:_calculate_offsets()

	return slot
end

StaggeredFormation.relinquish_slot = function (self, slot)
	table.remove(self._offsets, slot)
	self:_calculate_offsets()
end

StaggeredFormation._calculate_offsets = function (self)
	local mid_x = (#self._offsets - 1) / 2
	local mid_y = 0.5

	for index, offset in ipairs(self._offsets) do
		local base_index = index - 1
		local offset_slot_x = base_index - mid_x
		local offset_slot_y = base_index % 2 == 0 and mid_y or -mid_y
		local offset = Vector3(offset_slot_x * self._file_distance, offset_slot_y * self._rank_distance, 0)

		self._offsets[index]:store(offset)
	end
end

StaggeredFormation.offset = function (self, slot)
	return self._offsets[slot]:unbox()
end
