-- chunkname: @scripts/managers/news_ticker/news_ticker_token.lua

NewsTickerToken = NewsTickerToken or class()

NewsTickerToken.init = function (self, loader, job)
	self._loader = loader
	self._job = job
	self._name = "NewsTickerToken"
end

NewsTickerToken.name = function (self)
	return self._name
end

NewsTickerToken.info = function (self)
	local info = {}

	if self:done() and UrlLoader.success(self._loader, self._job) then
		info.body = UrlLoader.text(self._loader, self._job)
	else
		info.body = ""
		info.error = "Failed loading news ticker"
	end

	return info
end

NewsTickerToken.update = function (self)
	return
end

NewsTickerToken.done = function (self)
	return UrlLoader.done(self._loader, self._job)
end

NewsTickerToken.close = function (self)
	UrlLoader.unload(self._loader, self._job)
end
