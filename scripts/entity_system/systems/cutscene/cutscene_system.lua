﻿-- chunkname: @scripts/entity_system/systems/cutscene/cutscene_system.lua

CutsceneSystem = class(CutsceneSystem, ExtensionSystemBase)

CutsceneSystem.init = function (self, context, system_name)
	CutsceneSystem.super.init(self, context, system_name)

	self._cameras = {}
end

CutsceneSystem.active = function (self)
	return self._cutscene_active
end

CutsceneSystem.on_add_extension = function (self, world, unit, ...)
	CutsceneSystem.super.on_add_extension(self, world, unit, ...)

	local extension = ScriptUnit.extension(unit, "cutscene_system")
	local camera_name = extension:name()

	fassert(self._cameras[camera_name] == nil, "Camera %q already exists", camera_name)

	self._cameras[camera_name] = extension

	if self._level == nil then
		self._level = LevelHelper:current_level(world)
	end
end

CutsceneSystem.flow_cb_activate_cutscene = function (self, start_camera, end_event)
	for _, camera in pairs(self._cameras) do
		camera:finalize(self._cameras)
	end

	self._cutscene_active = true

	Managers.state.hud:set_huds_enabled_except(false)

	self._current_camera = ScriptUnit.extension(start_camera, "cutscene_system")

	self._current_camera:activate()

	self._end_event = end_event
end

CutsceneSystem.update = function (self, context, t)
	if self._cutscene_active then
		local done = self._current_camera:update(context.dt, t)

		if done then
			self._current_camera:deactivate()

			self._current_camera = self._current_camera:next_camera()

			if self._current_camera then
				self._current_camera:activate()
			else
				self._cutscene_active = false

				Managers.state.hud:set_huds_enabled_except(true)
				Level.trigger_event(self._level, self._end_event)
			end
		end
	end
end

CutsceneSystem.skip = function (self)
	self._cutscene_active = false

	Managers.state.hud:set_huds_enabled_except(true)
	Level.trigger_event(self._level, self._end_event)
end
