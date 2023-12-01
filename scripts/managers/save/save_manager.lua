-- chunkname: @scripts/managers/save/save_manager.win32.lua

require("scripts/managers/save/script_save_token")

SaveManager = class(SaveManager)

SaveManager.init = function (self, disable_cloud_save)
	if not disable_cloud_save and Cloud.enabled() then
		fassert(rawget(_G, "Steam"), "Steam is required for cloud saves")

		self._impl = Cloud
	else
		self._impl = SaveSystem
	end
end

SaveManager.auto_save = function (self, file_name, data, callback)
	local token = self._impl.auto_save(file_name, data)
	local save_token = ScriptSaveToken:new(self._impl, token)

	Managers.token:register_token(save_token, callback)

	return save_token
end

SaveManager.auto_load = function (self, file_name, callback)
	local token = self._impl.auto_load(file_name)
	local save_token = ScriptSaveToken:new(self._impl, token)

	Managers.token:register_token(save_token, callback)

	return save_token
end
