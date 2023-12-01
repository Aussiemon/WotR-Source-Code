-- chunkname: @scripts/managers/backend/script_backend_token.lua

ScriptBackendToken = class(ScriptBackendToken)

ScriptBackendToken.init = function (self, token)
	self._token = token
	self._info = {}
	self._name = "ScriptBackendToken"
end

ScriptBackendToken.name = function (self)
	return self._name
end

ScriptBackendToken.update = function (self)
	self._info = Backend.progress(self._token)
end

ScriptBackendToken.info = function (self)
	return self._info
end

ScriptBackendToken.done = function (self)
	return self._info.done
end

ScriptBackendToken.close = function (self)
	Backend.close(self._token)
end
