-- chunkname: @scripts/menu/menu_pages/sale_popup_menu_page.lua

require("scripts/utils/big_picture_input_handler")

SalePopupMenuPage = class(SalePopupMenuPage, MenuPage)
SalePopupMenuPage.menu_level = 2

SalePopupMenuPage.init = function (self, config, item_groups, world)
	SalePopupMenuPage.super.init(self, config, item_groups, world)

	self._world = world
	self._background_rect_layout_settings = {}
	self._background_rect = RectMenuContainer.create_from_config()
	self._header_container = ItemGridMenuContainer.create_from_config(item_groups.header_list)
	self._content_container = ItemGridMenuContainer.create_from_config(item_groups.content_texture_list, item_groups.content_header_list)
	self._content_description = ItemListMenuContainer.create_from_config(item_groups.content_description_list)
	self._navigation = ItemListMenuContainer.create_from_config(item_groups.content_navigation_list)
	self.config.selected_sale_item = 1
end

SalePopupMenuPage.on_enter = function (self)
	SalePopupMenuPage.super.on_enter(self)

	if self.config.on_enter_options then
		self._sale_items = self:_try_callback(self.config.callback_object, self.config.on_enter_options, self.config.on_enter_options_args) or {}
	end
end

SalePopupMenuPage.update = function (self, dt, t)
	SalePopupMenuPage.super.update(self, dt, t)
	self:_update_container_size(dt, t)
	self:_update_container_position(dt, t)
end

SalePopupMenuPage._update_container_size = function (self, dt, t)
	local layout_settings = MenuHelper:layout_settings(self.config.layout_settings)

	self._header_container:update_size(dt, t, self._gui, layout_settings.header_list)
	self._navigation:update_size(dt, t, self._gui, layout_settings.navigation)
	self._content_container:update_size(dt, t, self._gui, layout_settings.content_list)
	self._content_description:update_size(dt, t, self._gui, layout_settings.content_description)

	self._background_rect_layout_settings.color = layout_settings.background_color
	self._background_rect_layout_settings.absolute_width = self._header_container:width() + layout_settings.padding_left + layout_settings.padding_right
	self._background_rect_layout_settings.absolute_height = self._header_container:height() + self._content_container:height() + self._content_description:height() + layout_settings.padding_top + layout_settings.padding_bottom

	self._background_rect:update_size(dt, t, self._gui, self._background_rect_layout_settings)
end

SalePopupMenuPage._update_container_position = function (self, dt, t)
	local layout_settings = MenuHelper:layout_settings(self.config.layout_settings)
	local x, y = MenuHelper:container_position(self._background_rect, layout_settings)

	self._background_rect:update_position(dt, t, nil, x, y, self.config.z - 1)

	x = x + layout_settings.padding_left
	y = y + self._background_rect:height() - layout_settings.padding_top
	y = y - self._header_container:height()

	self._header_container:update_position(dt, t, layout_settings.header_list, x, y, self.config.z)

	y = y - self._content_container:height()

	self._content_container:update_position(dt, t, layout_settings.content_list, x, y, self.config.z)

	local width = self._background_rect:width()
	local navigationWidth = self._navigation:width()
	local navigationHeight = self._navigation:height()

	self._navigation:update_position(dt, t, layout_settings.navigation, x + width / 2 - navigationWidth / 2 - layout_settings.padding_left, y + navigationHeight + 5, self.config.z + 1)

	y = y - self._content_description:height()

	self._content_description:update_position(dt, t, layout_settings.content_description, x, y, self.config.z)
end

SalePopupMenuPage._update_input = function (self, input)
	if not self._big_picture_input_handler_active then
		SalePopupMenuPage.super._update_input(self, input)
	end
end

SalePopupMenuPage.render = function (self, dt, t)
	SalePopupMenuPage.super.render(self, dt, t)

	local layout_settings = MenuHelper:layout_settings(self.config.layout_settings)
	local color = layout_settings.background_color or {
		255,
		0,
		0,
		0
	}

	self._background_rect:render(dt, t, self._gui, self._background_rect_layout_settings)
	self._header_container:render(dt, t, self._gui, layout_settings.header_list)
	self._content_container:render(dt, t, self._gui, layout_settings.content_list)
	self._navigation:render(dt, t, self._gui, layout_settings.navigation)
	self._content_description:render(dt, t, self._gui, layout_settings.content_description)
end

SalePopupMenuPage.move_left = function (self)
	self:cb_previous_sale()
end

SalePopupMenuPage.move_right = function (self)
	self:cb_next_sale()
end

SalePopupMenuPage.sale_buy_item = function (self)
	return
end

SalePopupMenuPage._current_sale_item = function (self)
	if self.config.selected_sale_item <= #self.config.sale_popup_items then
		return self.config.sale_popup_items[self.config.selected_sale_item]
	end

	return nil
end

SalePopupMenuPage.cb_selection = function (self)
	return #self.config.sale_popup_items, self.config.selected_sale_item
end

SalePopupMenuPage.cb_new_selection = function (self, selection)
	self.config.selected_sale_item = selection
end

SalePopupMenuPage.cb_next_sale = function (self)
	self.config.selected_sale_item = self.config.selected_sale_item + 1

	if self.config.selected_sale_item > #self.config.sale_popup_items then
		self.config.selected_sale_item = 1
	end
end

SalePopupMenuPage.cb_previous_sale = function (self)
	self.config.selected_sale_item = self.config.selected_sale_item - 1

	if self.config.selected_sale_item < 1 then
		self.config.selected_sale_item = #self.config.sale_popup_items
	end
end

SalePopupMenuPage.cb_sale_header = function (self)
	local sale_item = self:_current_sale_item()

	if sale_item then
		return sale_item.header
	end

	return "HEADER"
end

SalePopupMenuPage.cb_sale_sub_header = function (self)
	local sale_item = self:_current_sale_item()

	if sale_item then
		return sale_item.sub_header
	end

	return "SUB_HEADER"
end

SalePopupMenuPage.cb_sale_price = function (self)
	local sale_item = self:_current_sale_item()

	if sale_item and sale_item.price then
		return sale_item.price
	end

	return ""
end

SalePopupMenuPage.cb_price_visible = function (self)
	local sale_item = self:_current_sale_item()

	if sale_item and sale_item.price then
		return true
	end

	return false
end

SalePopupMenuPage.cb_sale_texture = function (self)
	local sale_item = self:_current_sale_item()

	if sale_item then
		local atlas_settings = sale_item.texture_atlas_settings
		local material_name = sale_item.texture_material

		if sale_item.http_texture then
			atlas_settings = nil
		end

		return material_name, atlas_settings
	end

	return nil
end

SalePopupMenuPage.cb_sale_name = function (self)
	local sale_item = self:_current_sale_item()

	if sale_item then
		return sale_item.name
	end

	return "ITEM_NAME"
end

SalePopupMenuPage.cb_sale_description = function (self)
	local sale_item = self:_current_sale_item()

	if sale_item then
		return sale_item.description
	end

	return "ITEM_DESC"
end

SalePopupMenuPage.cb_buy_item = function (self)
	local sale_item = self:_current_sale_item()

	if sale_item.market_item then
		self._buy_item_popup = MenuHelper:create_purchase_market_item_popup_page(self._world, self, sale_item.market_item.entity_type, sale_item.market_item.market_item_name, sale_item.market_item.market_message_args, self.config.z + 5, self.config.sounds)

		self._menu_logic:change_page(self._buy_item_popup)
	end
end

SalePopupMenuPage.cb_item_disabled = function (self, disabled_func)
	local parent_page_args = {
		popup_page = self
	}

	return self:_try_callback(self.config.callback_object, disabled_func, parent_page_args)
end

SalePopupMenuPage.cb_cancel = function (self)
	Managers.sale_popup:on_popup_closed()
	SalePopupMenuPage.super.cb_cancel(self)
end

SalePopupMenuPage.create_from_config = function (compiler_data, page_config, parent_page, item_groups, callback_object)
	local config = {
		type = "sale_popup",
		parent_page = parent_page,
		callback_object = callback_object,
		on_enter_options = page_config.on_enter_options,
		on_enter_options_args = page_config.on_enter_options_args or {},
		on_item_selected = page_config.on_item_selected,
		on_cancel_exit = page_config.on_cancel_exit,
		render_parent_page = page_config.render_parent_page,
		show_revision = page_config.show_revision,
		no_cancel_to_parent_page = page_config.no_cancel_to_parent_page,
		z = page_config.z,
		layout_settings = page_config.layout_settings,
		sounds = page_config.sounds,
		environment = page_config.environment or parent_page and parent_page:environment(),
		sale_popup_items = page_config.sale_popup_items
	}

	return SalePopupMenuPage:new(config, item_groups, compiler_data.world)
end
