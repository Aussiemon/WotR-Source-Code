-- chunkname: @scripts/unit_extensions/objectives/flag_capture_point_server.lua

require("scripts/unit_extensions/objectives/capture_point_server_base")

FlagCapturePointServer = class(FlagCapturePointServer, CapturePointServerBase)

local DROPPED_FLAG_LIFETIME = 15
local CAPTURE_POINT_FLAG_HEALTH = 100

FlagCapturePointServer.init = function (self, world, unit)
	FlagCapturePointServer.super.init(self, world, unit)
	Unit.set_data(unit, "health", CAPTURE_POINT_FLAG_HEALTH)

	self._current_planter = nil
end

FlagCapturePointServer.update = function (self, unit, input, dt, context)
	local damage_ext = ScriptUnit.extension(unit, "damage_system")

	if damage_ext:is_dead() then
		self:set_owner("neutral")

		damage_ext._damage = 0
		damage_ext._dead = false
	end
end

FlagCapturePointServer.flow_cb_set_owner = function (self, team)
	self:set_owner(team, true)
end

FlagCapturePointServer.can_spawn_flag = function (self, picker_unit)
	local picker_player = Managers.player:owner(picker_unit)
	local picker_team_name = picker_player.team.name
	local owner_team = Managers.state.team:team_by_side(self._owner)

	return owner_team and owner_team.name == picker_team_name
end

FlagCapturePointServer.spawn_flag = function (self, picker_unit)
	local owner_team = Managers.state.team:team_by_side(self._owner)
	local team_name = owner_team.name
	local flag_unit_name = "units/weapons/wpn_capture_flag/wpn_capture_flag_" .. team_name
	local flag_unit = World.spawn_unit(self._world, flag_unit_name, Unit.world_position(self._unit, 0), Unit.world_rotation(self._unit, 0))

	Managers.state.entity:register_unit(self._world, flag_unit, team_name, DROPPED_FLAG_LIFETIME)

	return flag_unit
end

FlagCapturePointServer.can_plant_flag = function (self, planter_unit)
	local planter_player = Managers.player:owner(planter_unit)
	local planter_team_side = planter_player.team.side

	return self._owner == "neutral" and not self._current_planter and self._active[planter_team_side]
end

FlagCapturePointServer.set_current_planter = function (self, planter_unit)
	self._current_planter = planter_unit
end

FlagCapturePointServer.plant_flag = function (self, planter_unit)
	local planter_player = Managers.player:owner(planter_unit)
	local planter_team_side = planter_player.team.side

	self:set_owner(planter_team_side)
	self:set_current_planter(nil)
	Managers.state.event:trigger("flag_planted", planter_player, self._unit)
end
