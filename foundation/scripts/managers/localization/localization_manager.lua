﻿-- chunkname: @foundation/scripts/managers/localization/localization_manager.lua

LocalizationManager = class(LocalizationManager)

LocalizationManager.init = function (self, path)
	assert(not self._localizer, "LocalizationManager already initialized")

	self._localizer = Localizer(path)
	self._macros = {}
	self._macro_lookup_callback = callback(self._find_macro, self)
end

LocalizationManager.add_macro = function (self, macro, callback_function)
	self._macros[macro] = callback_function
end

LocalizationManager.lookup = function (self, text_id)
	fassert(self._localizer, "LocalizationManager not initialized")

	local str = Localizer.lookup(self._localizer, text_id) or "<" .. tostring(text_id) .. ">"

	return string.gsub(str, "%b$;[%a_]*:", self._macro_lookup_callback)
end

LocalizationManager.simple_lookup = function (self, text_id)
	fassert(self._localizer, "LocalizationManager not initialized")

	local str = Localizer.lookup(self._localizer, text_id) or "<" .. tostring(text_id) .. ">"

	return str
end

LocalizationManager._find_macro = function (self, macro_string)
	local arg_start = string.find(macro_string, ";")

	return self._macros[string.sub(macro_string, 2, arg_start - 1)](string.sub(macro_string, arg_start + 1, -2))
end

LocalizationManager.exists = function (self, text_id)
	fassert(self._localizer, "LocalizationManager not initialized")

	return Localizer.lookup(self._localizer, text_id) ~= nil
end

function L(text_id)
	return Managers.localizer:lookup(text_id)
end
