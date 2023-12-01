-- chunkname: @scripts/achievements/script_achievement_token.lua

ScriptAchievementToken = class(ScriptAchievementToken)

ScriptAchievementToken.init = function (self, token)
	self._token = token
	self._info = {}
	self._name = "ScriptAchievementToken"
end

ScriptAchievementToken.name = function (self)
	return self._name
end

ScriptAchievementToken.update = function (self)
	self._info = Achievement.progress(self._token)
end

ScriptAchievementToken.info = function (self)
	return self._info
end

ScriptAchievementToken.done = function (self)
	return self._info.done
end

ScriptAchievementToken.close = function (self)
	Achievement.close(self._token)
end
