-- chunkname: @scripts/managers/hud/hud_base.lua

HUDBase = class(HUDBase)

HUDBase.init = function (self, world, player)
	self._enabled = true
end

HUDBase.on_activated = function (self)
	return
end

HUDBase.on_deactivated = function (self)
	return
end

HUDBase.set_enabled = function (self, enabled)
	self._enabled = enabled
end

HUDBase.enabled = function (self)
	return self._enabled
end

HUDBase.post_update = function (self, dt, t)
	return
end

HUDBase.disabled_post_update = function (self, dt, t)
	return
end

HUDBase._handle_input_switch = function (self, elements, container, text_callback)
	local pad_active = Managers.input:pad_active(1)

	if self._pad_active == nil or pad_active ~= self._pad_active then
		self._pad_active = pad_active

		for _, id in pairs(elements) do
			local element = container:element(id)

			element.config.blackboard.text = text_callback(element, self._pad_active)
		end

		return pad_active
	end
end
