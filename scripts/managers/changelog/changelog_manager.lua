-- chunkname: @scripts/managers/changelog/changelog_manager.lua

require("scripts/managers/changelog/changelog_token")

ChangelogManager = class(ChangelogManager)

local TIMEOUT = 10

ChangelogManager.init = function (self)
	self._loader = UrlLoader()
	self._url = "http://services.paradoxplaza.com/head/feeds/wotr-patchnotes/content"
end

ChangelogManager.get_changelog = function (self, callback)
	local job = UrlLoader.load_text(self._loader, self._url)
	local changelog_token = ChangelogToken:new(self._loader, job)
	local timeout_time = Managers.time:time("main") + TIMEOUT

	Managers.token:register_token(changelog_token, callback, timeout_time)
end

ChangelogManager.update = function (self)
	UrlLoader.update(self._loader)
end

ChangelogManager.destroy = function (self)
	UrlLoader.destroy(self._loader)
end
