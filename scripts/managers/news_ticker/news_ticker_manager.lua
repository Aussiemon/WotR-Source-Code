﻿-- chunkname: @scripts/managers/news_ticker/news_ticker_manager.lua

require("scripts/managers/news_ticker/news_ticker_token")

NewsTickerManager = NewsTickerManager or class()

NewsTickerManager.init = function (self)
	if not rawget(_G, "UrlLoader") then
		return
	end

	self._loader = UrlLoader()
	self._url = "http://services.paradoxplaza.com/head/feeds/wotr-news-ticker/content"
end

NewsTickerManager.load = function (self, callback)
	if not rawget(_G, "UrlLoader") then
		return
	end

	local job = UrlLoader.load_text(self._loader, self._url)
	local token = NewsTickerToken:new(self._loader, job)

	Managers.token:register_token(token, callback)
end

NewsTickerManager.update = function (self)
	if not rawget(_G, "UrlLoader") then
		return
	end

	UrlLoader.update(self._loader)
end

NewsTickerManager.destroy = function (self)
	if not rawget(_G, "UrlLoader") then
		return
	end

	UrlLoader.destroy(self._loader)
end
