﻿-- chunkname: @scripts/managers/input/input_filters.lua

require("foundation/scripts/input/input_filters")

FilterAxisScaleRampInvertedYDt = class(FilterAxisScaleRampInvertedYDt, FilterAxisScaleRampDt)

FilterAxisScaleRampInvertedYDt.update = function (self, source, dt)
	FilterAxisScaleRampInvertedYDt.super.update(self, source, dt)

	self._update_value.y = -self._update_value.y
end

InputFilterClasses.FilterAxisScaleRampInvertedYDt = FilterAxisScaleRampInvertedYDt
