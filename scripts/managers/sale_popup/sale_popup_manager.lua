-- chunkname: @scripts/managers/sale_popup/sale_popup_manager.lua

require("scripts/managers/sale_popup/sale_popup_token")
require("scripts/managers/sale_popup/sale_popup_texture_manager")

SalePopupManager = SalePopupManager or class()

local TIMEOUT = 10

SalePopupManager.init = function (self, config_url)
	self._loader = UrlLoader()
	self._url = config_url
	self._sale_items = {}
	self._texture_load_queue = {}
	self._textures_to_load = 0
	self._texture_data = SalePopupTextureManager:new()
	self._new_data = false
	self._important_data = false
end

SalePopupManager.load_sale_config = function (self)
	self._sale_data_loaded = false

	if self._url then
		self:get_sale_config(callback(self, "cb_sale_popup_data_loaded"))
	end
end

SalePopupManager.cb_sale_popup_data_loaded = function (self, info)
	if info.failed then
		return
	end

	local sale_config = info.body

	if sale_config and type(sale_config) ~= "string" and sale_config.items then
		for _, config in pairs(sale_config.items) do
			if config.type == "news" then
				local texture_material, texture_settings

				if config.texture_material then
					texture_material = config.texture_material

					local atlas_table = rawget(_G, config.texture_atlas_settings_table)

					if atlas_table then
						texture_settings = atlas_table[config.texture_atlas_settings]
					end
				else
					texture_material = "sale_popup_content"
					texture_settings = sale_popup_atlas.news_popup
				end

				self._sale_items[#self._sale_items + 1] = {
					header = config.header,
					sub_header = config.sub_header,
					name = config.news_name,
					description = config.news_description,
					texture_material = texture_material,
					texture_atlas_settings = texture_settings
				}

				if config.http_texture then
					self._texture_load_queue[#self._texture_load_queue + 1] = {
						#self._sale_items,
						config.http_texture
					}
					self._textures_to_load = self._textures_to_load + 1
				end
			else
				local item_settings

				if config.type == "armour" then
					item_settings = Armours[config.item]
				elseif config.type == "gear" then
					item_settings = Gear[config.item]
				elseif config.typ == "helmet" then
					item_settings = Helmets[config.item]
				end

				if item_settings then
					local market_item_config = {
						entity_type = config.type,
						entity_name = config.item,
						market_item_name = config.type .. "|" .. config.item,
						market_message_args = {
							item_settings.ui_header
						}
					}
					local market_items = Managers.persistence:market().items
					local market_item = market_items[market_item_config.market_item_name]
					local market_item_price

					if market_item then
						local prices = market_item.prices
						local price_table = prices[1]

						if price_table then
							market_item_price = tostring(price_table.price)
						end
					end

					self._sale_items[#self._sale_items + 1] = {
						texture_material = "outfit_atlas",
						header = config.header,
						sub_header = config.sub_header,
						market_item = market_item_config,
						name = L(item_settings.ui_header),
						description = L(item_settings.ui_description),
						price = market_item_price,
						texture_atlas_settings = OutfitAtlas[item_settings.ui_texture]
					}
				end
			end
		end

		self._new_data = true
	end

	if self._texture_load_queue[self._textures_to_load] then
		local texture_url = self._texture_load_queue[self._textures_to_load][2]

		self._texture_data:get_texture(texture_url, callback(self, "cb_sale_popup_texture_loaded"))
	end
end

SalePopupManager.add_item_in_front = function (self, sale_item)
	local sale_items = {}

	sale_items[#sale_items + 1] = sale_item

	for _, item in ipairs(self._sale_items) do
		sale_items[#sale_items + 1] = item
	end

	self._sale_items = sale_items
	self._new_data = true
end

SalePopupManager.cb_sale_popup_texture_loaded = function (self, info)
	local item_index = self._texture_load_queue[self._textures_to_load][1]

	if not info.failed then
		self._sale_items[item_index].http_texture = info.body
	end

	self._textures_to_load = self._textures_to_load - 1

	if self._textures_to_load == 0 then
		self._sale_data_loaded = true
	else
		local texture_url = self._texture_load_queue[self._textures_to_load][2]

		self._texture_data:get_texture(texture_url, callback(self, "cb_sale_popup_texture_loaded"))
	end
end

SalePopupManager.create_daily_award_item = function (self, amount)
	local daily_win_notification = {
		texture_material = "sale_popup_content",
		display_once = true,
		sub_header = "",
		header = L("daily_coin_bonus_header"),
		name = L("daily_coin_bonus_content_header"),
		description = L("daily_coin_bonus_content_description"),
		price = tostring(amount),
		texture_atlas_settings = sale_popup_atlas.coins_popup
	}

	self:add_item_in_front(daily_win_notification)
end

SalePopupManager.create_round_award_item = function (self, amount)
	self:create_daily_award_item(amount)
end

SalePopupManager.create_coin_dlc_item = function (self, coins)
	local coin_dlc_notification = {
		texture_material = "sale_popup_content",
		display_once = true,
		header = L("coin_dlc_header"),
		sub_header = L("coin_dlc_sub_header"),
		name = L("coin_dlc_content_header"),
		description = L("coin_dlc_content_description"),
		price = tostring(coins),
		texture_atlas_settings = sale_popup_atlas.coins_popup
	}

	self._important_data = true

	self:add_item_in_front(coin_dlc_notification)
end

SalePopupManager.on_popup_closed = function (self)
	local items_to_remove = {}

	for index, item in ipairs(self._sale_items) do
		if item.display_once then
			items_to_remove[#items_to_remove + 1] = index
		end
	end

	for i = #items_to_remove, 1, -1 do
		table.remove(self._sale_items, items_to_remove[i])
	end
end

SalePopupManager.data_loaded = function (self)
	return self._sale_data_loaded
end

SalePopupManager.important_data = function (self, reset)
	local important_data = self._important_data

	if reset then
		self._important_data = false
	end

	return important_data
end

SalePopupManager.new_data = function (self, reset)
	local new_data = self._new_data

	if reset then
		self._new_data = false
	end

	return new_data
end

SalePopupManager.get_loaded_data = function (self)
	return self._sale_items
end

SalePopupManager.clear_loaded_data = function (self)
	self._sale_items = {}
	self._texture_load_queue = {}
	self._textures_to_load = 0
	self._important_data = false
	self._new_data = false
end

SalePopupManager.get_sale_config = function (self, callback)
	local job = UrlLoader.load_text(self._loader, self._url)
	local sale_token = SalePopupToken:new(self._loader, job)
	local timeout_time = Managers.time:time("main") + TIMEOUT

	Managers.token:register_token(sale_token, callback, timeout_time)
end

SalePopupManager.update = function (self)
	UrlLoader.update(self._loader)
	self._texture_data:update()
end

SalePopupManager.destroy = function (self)
	self._texture_data:destroy()
	UrlLoader.destroy(self._loader)
end
