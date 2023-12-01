-- chunkname: @scripts/unit_extensions/human/ai_player_unit/ai_steering.lua

AISteering = class(AISteering)

local settings = AISettings.steering

AISteering.init = function (self, unit, locomotion)
	self._unit = unit
	self._locomotion = locomotion
	self._seek_active = false
	self._seek_target = Vector3Box()
	self._seek_force = Vector3Box()
	self._arrive_active = false
	self._arrive_target = Vector3Box()
	self._arrive_force = Vector3Box()
	self._avoid_units = {}
	self._avoid_force = Vector3Box()
end

AISteering.update = function (self, t, dt)
	Profiler.start("AISteering")

	if self._seek_active then
		self:_update_seek(t, dt)
	end

	if self._arrive_active then
		self:_update_arrive(t, dt)
	end

	self:_update_avoid()
	Profiler.stop()
end

AISteering._debug_draw = function (self)
	local drawer = Managers.state.debug:drawer({
		mode = "immediate",
		name = "steering"
	})
	local unit_pos = Unit.world_position(self._unit, 0)

	drawer:sphere(self._seek_target:unbox(), 0.25, Color(255, 0, 0))
	drawer:vector(unit_pos + Vector3.up(), self._seek_force:unbox(), Color(255, 0, 0))
	drawer:sphere(self._arrive_target:unbox(), 0.25, Color(0, 255, 0))
	drawer:vector(unit_pos + Vector3.up(), self._arrive_force:unbox(), Color(0, 255, 0))
	drawer:vector(unit_pos + Vector3.up(), self._avoid_force:unbox(), Color(0, 0, 255))
	drawer:vector(unit_pos + Vector3.up(), self._locomotion:get_velocity())
end

AISteering._create_or_update_arrive_timer = function (self, t, dt)
	self._arrive_time_end = self._arrive_time_end or t + settings.arrive_time

	return t >= self._arrive_time_end
end

AISteering._clear_arrive_timer = function (self)
	self._arrive_time_end = nil
end

AISteering.seek = function (self, target_pos, arrive_callback)
	self._seek_active = true

	self._seek_target:store(target_pos)

	self._arrive_callback = arrive_callback

	self:_reset_arrive()
end

AISteering._update_seek = function (self, t, dt)
	local unit_pos = Unit.world_position(self._unit, 0)
	local offset = self._seek_target:unbox() - unit_pos
	local distance = Vector3.length(offset)

	if distance <= settings.arrive_threshold_far then
		local arrived = self:_create_or_update_arrive_timer(t, dt)

		if arrived or distance <= settings.arrive_threshold then
			self:_clear_arrive_timer()

			if self._arrive_callback then
				self._arrive_callback(self._unit)
			end
		end
	end

	local desired_vel = Vector3.normalize(offset) * AISettings.locomotion.jog_threshold
	local force = desired_vel - self._locomotion:get_velocity()

	self._seek_force:store(force)
end

AISteering._reset_seek = function (self)
	self._seek_active = false

	self._seek_force:store(Vector3.zero())
end

AISteering.arrive = function (self, target_pos, arrive_callback)
	self._arrive_active = true

	self._arrive_target:store(target_pos)

	self._arrive_callback = arrive_callback

	self:_reset_seek()
end

AISteering._update_arrive = function (self, t, dt)
	local unit_pos = Unit.world_position(self._unit, 0)
	local offset = self._arrive_target:unbox() - unit_pos
	local distance = Vector3.length(offset)

	if distance <= settings.arrive_threshold_far then
		local arrived = self:_create_or_update_arrive_timer(t, dt)

		if arrived or distance <= settings.arrive_threshold then
			self:_clear_arrive_timer()

			if self._arrive_callback then
				self._arrive_callback(self._unit)
			end
		end
	end

	local max_speed = math.clamp(math.max(distance^2, distance^0.5), 0, AISettings.locomotion.jog_threshold)
	local desired_vel = Vector3.normalize(offset) * max_speed
	local force = desired_vel - self._locomotion:get_velocity()

	self._arrive_force:store(force)
end

AISteering._reset_arrive = function (self)
	self._arrive_active = false

	self._arrive_force:store(Vector3.zero())
end

AISteering.avoid = function (self, avoid_unit, multiplier)
	self._avoid_units[avoid_unit] = multiplier or 1
end

AISteering._update_avoid = function (self)
	local sum_avoid_force = Vector3.zero()
	local unit_pos = Unit.world_position(self._unit, 0)
	local unit_rot = Unit.world_rotation(self._unit, 0)

	for unit, multiplier in pairs(self._avoid_units) do
		if Unit.alive(unit) then
			local avoid_unit_pos = Unit.world_position(unit, 0)
			local offset = unit_pos - avoid_unit_pos
			local distance = Vector3.length(offset)
			local force_mag = multiplier / distance^2

			if force_mag >= settings.avoid_force_threshold then
				local force_dir = Vector3.normalize(offset)
				local force = force_dir * force_mag

				sum_avoid_force = sum_avoid_force + force
			else
				self._avoid_units[unit] = nil
			end
		else
			self._avoid_units[unit] = nil
		end
	end

	self._avoid_force:store(sum_avoid_force)
end

AISteering._reset_avoid = function (self)
	table.clear(self._avoid_units)
	self._avoid_force:store(Vector3.zero())
end

AISteering.reset = function (self)
	self:_reset_seek()
	self:_reset_arrive()
	self:_reset_avoid()
end

AISteering.force = function (self)
	local seek_force = self._seek_force:unbox()
	local arrive_force = self._arrive_force:unbox()
	local avoid_force = self._avoid_force:unbox()
	local total_force = Vector3.zero()

	if self._seek_active and self._arrive_active then
		total_force = total_force + arrive_force
	else
		total_force = total_force + seek_force + arrive_force
	end

	return seek_force + arrive_force + avoid_force
end
