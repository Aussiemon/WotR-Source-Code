-- chunkname: @scripts/managers/changelog/changelog_token.lua

ChangelogToken = class(ChangelogToken)

ChangelogToken.init = function (self, loader, job)
	self._loader = loader
	self._job = job
	self._name = "ChangelogToken"
end

ChangelogToken.name = function (self)
	return self._name
end

ChangelogToken.info = function (self)
	local info = {}

	if self:done() and UrlLoader.success(self._loader, self._job) then
		info.body = UrlLoader.text(self._loader, self._job)
	else
		info.body = ""
		info.error = "Failed loading changelog"
	end

	return info
end

ChangelogToken.update = function (self)
	return
end

ChangelogToken.done = function (self)
	return UrlLoader.done(self._loader, self._job)
end

ChangelogToken.close = function (self)
	UrlLoader.unload(self._loader, self._job)
end
