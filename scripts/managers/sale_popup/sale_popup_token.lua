-- chunkname: @scripts/managers/sale_popup/sale_popup_token.lua

SalePopupToken = SalePopupToken or class()

SalePopupToken.init = function (self, loader, job)
	self._loader = loader
	self._job = job
	self._name = "SalePopupToken"
end

SalePopupToken.name = function (self)
	return self._name
end

SalePopupToken.info = function (self)
	local info = {}

	if self:done() and UrlLoader.success(self._loader, self._job) then
		info.body = UrlLoader.text(self._loader, self._job)
	else
		info.body = ""
		info.error = "Failed loading sale popup"
	end

	return info
end

SalePopupToken.update = function (self)
	return
end

SalePopupToken.done = function (self)
	return UrlLoader.done(self._loader, self._job)
end

SalePopupToken.close = function (self)
	UrlLoader.unload(self._loader, self._job)
end
