-- chunkname: @scripts/unit_extensions/human/ai_player_unit/states/ai_stunned.lua

require("scripts/unit_extensions/human/base/states/human_stunned")

AIStunned = class(AIStunned, HumanStunned)

AIStunned.enter = function (self, old_state)
	AIStunned.super.enter(self, old_state)
	self:safe_action_interrupt("stunned")

	local animation_stun_time = PlayerUnitDamageSettings.stun.duration

	self._stun_time = animation_stun_time + Managers.time:time("game")

	self:anim_event_with_variable_float("stun_back_head_down", "stun_time", animation_stun_time)
end

AIStunned.exit = function (self, new_state)
	self:anim_event("stun_end")

	self._stun_time = nil
end

AIStunned.update = function (self, dt, t)
	if t > self._stun_time then
		self:change_state("onground")
	end
end

AIStunned.post_update = function (self, dt, t)
	return
end

AIStunned.melee_attack = function (self, ...)
	return
end

AIStunned.block_attack = function (self, ...)
	return
end

AIStunned.wield_weapon = function (self, ...)
	return
end

AIStunned._abort_pose = function (self)
	AIStunned.super._abort_pose(self)

	self._internal.melee_attack = false
end

AIStunned.swing_finished = function (self)
	AIStunned.super.swing_finished(self)

	self._internal.melee_attack = false
end
