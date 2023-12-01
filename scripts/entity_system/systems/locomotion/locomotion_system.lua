-- chunkname: @scripts/entity_system/systems/locomotion/locomotion_system.lua

LocomotionSystem = class(LocomotionSystem, ExtensionSystemBase)

require("scripts/unit_extensions/default_player_unit/player_unit_locomotion")
require("scripts/unit_extensions/default_player_unit/player_husk_locomotion")
require("scripts/unit_extensions/horse/horse_locomotion")

LocomotionSystem.init = function (self, ...)
	self._prioritized_extensions = {
		"PlayerHuskLocomotion",
		"HorseLocomotion",
		"PlayerUnitLocomotion"
	}

	LocomotionSystem.super.init(self, ...)
	Managers.state.event:register(self, "animation_callback", "animation_callback")
end

LocomotionSystem.animation_callback = function (self, extension, unit, callback, param)
	local internal = ScriptUnit.extension(unit, extension)

	internal:anim_cb(callback, unit, param)
end
