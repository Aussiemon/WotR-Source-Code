-- chunkname: @scripts/managers/sale_popup/sale_popup_texture_manager.lua

require("scripts/managers/sale_popup/sale_popup_texture_token")

SalePopupTextureManager = SalePopupTextureManager or class()

local TIMEOUT = 30

SalePopupTextureManager.init = function (self)
	self._loader = UrlLoader()
	self._url = nil
end

SalePopupTextureManager.get_texture = function (self, url, callback)
	local job = UrlLoader.load_texture(self._loader, url, "sale_popup", 1024, 1024)
	local sale_token = SalePopupTextureToken:new(self._loader, job)
	local timeout_time = Managers.time:time("main") + TIMEOUT

	Managers.token:register_token(sale_token, callback, timeout_time)
end

SalePopupTextureManager.update = function (self)
	UrlLoader.update(self._loader)
end

SalePopupTextureManager.destroy = function (self)
	UrlLoader.destroy(self._loader)
end
