﻿-- chunkname: @scripts/unit_extensions/objectives/grail_spawn_point_offline.lua

GrailSpawnPointOffline = class(GrailSpawnPointOffline, FlagCapturePointServer)

local DROPPED_GRAIL_LIFETIME = 5

GrailSpawnPointOffline.SERVER_ONLY = false
GrailSpawnPointOffline.OFFLINE_ONLY = true

GrailSpawnPointOffline.event_round_started = function (self, params)
	return
end
