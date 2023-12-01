-- chunkname: @scripts/managers/sale_popup/sale_popup_texture_token.lua

SalePopupTextureToken = SalePopupTextureToken or class()

SalePopupTextureToken.init = function (self, loader, job)
	self._loader = loader
	self._job = job
	self._name = "SalePopupTextureToken"
end

SalePopupTextureToken.name = function (self)
	return self._name
end

SalePopupTextureToken.info = function (self)
	if UrlLoader.success(self._loader, self._job) then
		return UrlLoader.texture(self._loader, self._job)
	else
		return "Failed loading sale popup texture"
	end
end

SalePopupTextureToken.update = function (self)
	return
end

SalePopupTextureToken.done = function (self)
	return UrlLoader.done(self._loader, self._job)
end

SalePopupTextureToken.close = function (self)
	UrlLoader.unload(self._loader, self._job)
end
