-- chunkname: @scripts/managers/death_zone/death_zone_manager.lua

require("scripts/managers/death_zone/death_zone")
require("scripts/managers/death_zone/damage_zone")
require("scripts/managers/death_zone/damage_over_time_zone")

DeathZoneManager = class(DeathZoneManager)

DeathZoneManager.init = function (self, world)
	self._world = world
	self._zones = {}
	self._extensions = {
		"PlayerUnitDamage",
		"PlayerHuskDamage",
		"HorseDamage"
	}

	Managers.state.event:register(self, "event_round_pre_started", "event_round_pre_started")
end

DeathZoneManager.event_round_pre_started = function (self)
	self._level = LevelHelper:current_level(self._world)
end

DeathZoneManager.activate_death_zone = function (self, volume_name)
	fassert(Level.has_volume(self._level, volume_name), "Level has no volume with name %q", volume_name)
	fassert(self._zones[volume_name] == nil, "Volume %q already activated", volume_name)

	self._zones[volume_name] = DeathZone:new(self._level, volume_name)
end

DeathZoneManager.activate_damage_zone = function (self, volume_name, damage)
	fassert(Level.has_volume(self._level, volume_name), "Level has no volume with name %q", volume_name)
	fassert(self._zones[volume_name] == nil, "Volume %q already activated", volume_name)

	self._zones[volume_name] = DamageZone:new(self._level, volume_name, damage)
end

DeathZoneManager.activate_damage_over_time_zone = function (self, volume_name, damage, period)
	fassert(Level.has_volume(self._level, volume_name), "Level has no volume with name %q", volume_name)
	fassert(self._zones[volume_name] == nil, "Volume %q already activated", volume_name)

	self._zones[volume_name] = DamageOverTimeZone:new(self._level, volume_name, damage, period)
end

DeathZoneManager.deactivate_zone = function (self, volume_name)
	fassert(self._zones[volume_name], "No zone with name %q", volume_name)

	self._zones[volume_name] = nil
end

DeathZoneManager.update = function (self, dt, t)
	Profiler.start("DeathZoneManager")

	for _, zone in pairs(self._zones) do
		for _, extension_name in pairs(self._extensions) do
			local units = Managers.state.entity:get_entities(extension_name)

			for unit, _ in pairs(units) do
				zone:update(dt, t, unit)
			end
		end
	end

	Profiler.stop()
end
