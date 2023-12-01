﻿-- chunkname: @scripts/unit_extensions/objectives/capture_point_client_base.lua

CapturePointClientBase = class(CapturePointClientBase)
CapturePointClientBase.CLIENT_ONLY = true
CapturePointClientBase.SYSTEM = "objective_system"

CapturePointClientBase.init = function (self, world, unit)
	self._world = world
	self._unit = unit
	self._id = nil
	self._active = {}
	self._blackboard = {
		owner_team_side = "neutral",
		active_team_sides = {}
	}

	self:set_owner("neutral")
end

CapturePointClientBase.set_game_object_id = function (self, obj_id, game)
	self._id = obj_id
	self._game = game
end

CapturePointClientBase.objective = function (self, side)
	local unit = self._unit

	return Unit.get_data(unit, "hud", "objective", side, "name"), Unit.get_data(unit, "hud", "objective", side, "priority")
end

CapturePointClientBase.update = function (self, unit, input, dt, context)
	local game = Managers.state.network:game()

	if game and self._id then
		local owner = NetworkLookup.team[GameSession.game_object_field(game, self._id, "owner")]

		if owner ~= self._owner then
			self:set_owner(owner)
		end

		for _, team in pairs(Managers.state.team:sides()) do
			local active = GameSession.game_object_field(game, self._id, team .. "_active")

			if active ~= self._active[team] then
				self:set_active(team, active)
			end
		end
	end
end

CapturePointClientBase.set_active = function (self, team_side, active)
	local no_active_before = true
	local no_active_after = true

	self._blackboard.active_team_sides[team_side] = active

	for _, team_side in pairs(Managers.state.team:sides()) do
		if self._blackboard.active_team_sides[team_side] then
			no_active_after = false
		end

		if self._active[team_side] then
			no_active_before = false
		end
	end

	if active and no_active_before then
		Managers.state.event:trigger("objective_activated", self._blackboard, self._unit)
	elseif not active and no_active_after then
		Managers.state.event:trigger("objective_deactivated", self._unit)
	end

	self._active[team_side] = active
end

CapturePointClientBase.set_owner = function (self, owner)
	Unit.set_data(self._unit, "side", owner)

	self._owner = owner
	self._blackboard.owner_team_side = owner

	local team = Managers.state.team:team_by_side(owner)
	local team_name

	if team then
		team_name = team.name
	else
		team_name = "neutral"
	end

	Unit.flow_event(self._unit, "lua_set_team_name_" .. team_name)
end

CapturePointClientBase.level_index = function (self)
	return GameSession.game_object_field(self._game, self._id, "level_unit_index")
end

CapturePointClientBase.active = function (self, side)
	return self._active[side]
end

CapturePointClientBase.owned = function (self, side)
	return self._owner == side
end

CapturePointClientBase.destroy = function (self)
	return
end
