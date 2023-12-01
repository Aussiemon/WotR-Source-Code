-- chunkname: @scripts/managers/music/music_manager.lua

require("scripts/settings/sound_ducking_settings")
require("foundation/scripts/util/sound_ducking/ducking_handler")

MusicManager = class(MusicManager)

MusicManager.init = function (self)
	self._world = Managers.world:create_world("music_world", nil, nil, nil, Application.DISABLE_PHYSICS, Application.DISABLE_RENDERING)
	self._timpani_world = World.timpani_world(self._world)
end

MusicManager.stop_all_sounds = function (self)
	self._timpani_world:stop_all()
end

MusicManager.trigger_event = function (self, event_name)
	return TimpaniWorld.trigger_event(self._timpani_world, event_name)
end

MusicManager.set_parameter = function (self, id, variable, value)
	TimpaniWorld.set_parameter(self._timpani_world, id, variable, value)
end

MusicManager.update = function (self, dt, t)
	return
end
