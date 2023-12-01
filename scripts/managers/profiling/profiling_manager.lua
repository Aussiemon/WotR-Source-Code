-- chunkname: @scripts/managers/profiling/profiling_manager.lua

ProfilingManager = class(ProfilingManager)

ProfilingManager.init = function (self)
	self._frame = 0
	self._perf_pfx = "[Perf]"
	self._longest_frame = 0
end

ProfilingManager.update = function (self, dt, t)
	self._frame = self._frame + 1

	local viewport_name = Managers.player:player(1).viewport_name
	local camera_pos = ""
	local camera_dir = ""

	if viewport_name then
		camera_pos = Managers.state.camera:camera_position(viewport_name)
		camera_dir = Quaternion.forward(Managers.state.camera:camera_rotation(viewport_name))
	end

	if dt > self._longest_frame then
		self._longest_frame = dt
		self._longest_frame_camera_pos = camera_pos
		self._longest_frame_camera_dir = camera_dir
	end

	if self._frame >= GameSettingsDevelopment.performance_profiling.frames_between_print then
		self._frame = 0

		print(self._perf_pfx, "|DT", tostring(dt), "|CAMERAPOS", camera_pos, "|CAMERADIR", camera_dir, "|LONGESTDT", tostring(self._longest_frame), "|CAMERAPOS_L", self._longest_frame_camera_pos, "|CAMERADIR_L", self._longest_frame_camera_dir)
	end
end

ProfilingManager.level_loaded = function (self, level_name)
	print(self._perf_pfx, "|LEVEL", level_name)
end

ProfilingManager.destroy = function (self)
	return
end
