-- chunkname: @scripts/unit_extensions/objectives/grail_spawn_point_client.lua

require("scripts/unit_extensions/objectives/capture_point_client_base")

GrailSpawnPointClient = class(GrailSpawnPointClient, CapturePointClientBase)

GrailSpawnPointClient.init = function (self, world, unit)
	GrailSpawnPointClient.super.init(self, world, unit)
end

GrailSpawnPointClient.can_spawn_flag = function (self, picker_unit)
	local picker_player = Managers.player:owner(picker_unit)

	if not picker_player.team then
		return false
	end

	local picker_team_side = picker_player.team.side

	return self._active[picker_team_side]
end

GrailSpawnPointClient.can_plant_flag = function (self, planter_unit)
	return false
end

GrailSpawnPointClient.set_active = function (self, team, active)
	GrailSpawnPointClient.super.set_active(self, team, active)

	if active then
		Unit.flow_event(self._unit, "lua_activated_on_client_" .. team)
	else
		Unit.flow_event(self._unit, "lua_deactivated_on_client_" .. team)
	end
end

GrailSpawnPointClient.destroy = function (self)
	return
end
