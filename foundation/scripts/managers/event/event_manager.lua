﻿-- chunkname: @foundation/scripts/managers/event/event_manager.lua

EventManager = class(EventManager)

EventManager.init = function (self)
	self._events = {}
end

EventManager.register = function (self, object, ...)
	for i = 1, select("#", ...), 2 do
		local event_name = select(i, ...)
		local callback_name = select(i + 1, ...)

		fassert(type(object) == "table" and type(object[callback_name]) == "function", "No function found with name %q on supplied object", callback_name)

		self._events[event_name] = self._events[event_name] or {}
		self._events[event_name][object] = callback_name
	end
end

EventManager.unregister = function (self, event_name, object)
	if object then
		self._events[event_name][object] = nil
	else
		self._events[event_name] = nil
	end
end

EventManager.trigger = function (self, event_name, ...)
	local events = self._events[event_name]

	if events then
		for object, callback_name in pairs(self._events[event_name]) do
			object[callback_name](object, ...)
		end
	end

	if false then
		-- Nothing
	end
end
