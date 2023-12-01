-- chunkname: @scripts/menu/menu_items/menu_item.lua

require("scripts/menu/menu_containers/floating_tooltip_menu_container")

MenuItem = class(MenuItem)

MenuItem.init = function (self, config, world)
	self.config = config
	self._world = world
	self._highlighted = false
	self._width = 0
	self._height = 0
	self._x = 0
	self._y = 0
	self._mouse_x = nil
	self._mouse_y = nil
	self._mouse_area_x = nil
	self._mouse_area_y = nil
	self._mouse_area_width = nil
	self._mouse_area_height = nil

	if config.visible == nil then
		config.visible = true
	end

	if config.removed == nil then
		config.removed = false
	end

	if self.config.page then
		self.config.page:set_parent_item(self)
	end

	if self.config.floating_tooltip then
		self._floating_tooltip = FloatingTooltipMenuContainer.create_from_config(self.config.floating_tooltip.header, self.config.floating_tooltip.text, self)
	end
end

MenuItem.set_mouse_position = function (self, x, y)
	self._mouse_x = x
	self._mouse_y = y
end

MenuItem.on_highlight = function (self, ignore_sound)
	self._highlighted = true

	if self.config.on_highlight then
		self:_try_callback(self.config.callback_object, self.config.on_highlight, unpack(self.config.on_highlight_args or {}))
	end

	if not ignore_sound and self.config.sounds.hover then
		local timpani_world = World.timpani_world(self._world)

		TimpaniWorld.trigger_event(timpani_world, self.config.sounds.hover)
	end
end

MenuItem.on_lowlight = function (self)
	self._highlighted = false
end

MenuItem.on_select = function (self, ignore_sound)
	self:_try_callback(self.config.callback_object, self.config.on_select, unpack(self.config.on_select_args or {}))

	if not ignore_sound and self.config.sounds.select then
		local timpani_world = World.timpani_world(self._world)

		TimpaniWorld.trigger_event(timpani_world, self.config.sounds.select)
	end
end

MenuItem.on_select_down = function (self, mouse_pos)
	return
end

MenuItem.set_callback_name = function (self, event_name, function_name)
	self.config[event_name] = function_name
end

MenuItem.on_page_enter = function (self, on_cancel)
	return
end

MenuItem.on_page_exit = function (self, on_cancel)
	return
end

MenuItem.disabled = function (self)
	return self.config.disabled
end

MenuItem.update_disabled = function (self)
	if self.config.disabled_func then
		self.config.disabled = self.config.disabled_func()
	end
end

MenuItem.visible = function (self)
	return self.config.visible
end

MenuItem.update_visible = function (self)
	if self.config.visible_func then
		self.config.visible = self.config.visible_func()
	end
end

MenuItem.visible_in_demo = function (self)
	return false
end

MenuItem.removed = function (self)
	return self.config.removed
end

MenuItem.update_remove = function (self)
	if self.config.remove_func then
		self.config.removed = self.config.remove_func()
	end
end

MenuItem.set_hidden = function (self, hidden)
	self.config.hidden = hidden
end

MenuItem.set_column = function (self, column)
	self.config.column = column
end

MenuItem.set_page = function (self, page)
	self.config.page = page
end

MenuItem.page = function (self)
	return self.config.page
end

MenuItem.is_mouse_inside = function (self, mouse_x, mouse_y)
	local x1 = self._mouse_area_x or self._x
	local y1 = self._mouse_area_y or self._y
	local x2 = x1 + (self._mouse_area_width or self._width)
	local y2 = y1 + (self._mouse_area_height or self._height)

	return x1 <= mouse_x and mouse_x <= x2 and y1 <= mouse_y and mouse_y <= y2
end

MenuItem.on_move_left = function (self)
	return
end

MenuItem.on_move_right = function (self)
	return
end

MenuItem._try_callback = function (self, callback_object, callback_name, ...)
	if callback_object and callback_name and callback_object[callback_name] then
		return callback_object[callback_name](callback_object, ...)
	end
end

MenuItem.highlightable = function (self)
	return not self:disabled() and self:visible() and not self:removed()
end

MenuItem.width = function (self)
	return self._width
end

MenuItem.height = function (self)
	return self._height
end

MenuItem.x = function (self)
	return self._x
end

MenuItem.y = function (self)
	return self._y
end

MenuItem.z = function (self)
	return self._z
end

MenuItem.name = function (self)
	return self.config.name
end

MenuItem.menu_activated = function (self)
	if self.config.page then
		self.config.page:menu_activated()
	end
end

MenuItem.menu_deactivated = function (self, tab)
	tab = tab or {}

	if tab[self] then
		-- Nothing
	end

	tab[self] = true

	if self.config.page then
		self.config.page:menu_deactivated(tab)
	end
end

MenuItem.update_size = function (self, dt, t, gui)
	if self._floating_tooltip then
		if self._mouse_x and self._mouse_y and not self._floating_tooltip:is_playing() and self:visible() and not self.config.hidden then
			self._floating_tooltip:play()
		elseif (not self._mouse_x or not self._mouse_y) and self._floating_tooltip:is_playing() then
			self._floating_tooltip:stop()
		end

		local layout_settings = MenuHelper:layout_settings(self.config.floating_tooltip.layout_settings)

		self._floating_tooltip:update_size(dt, t, gui, layout_settings)
	end
end

MenuItem.update_position = function (self, dt, t)
	if self._floating_tooltip then
		local layout_settings = MenuHelper:layout_settings(self.config.floating_tooltip.layout_settings)

		self._floating_tooltip:update_position(dt, t, layout_settings, self._mouse_x, self._mouse_y, 999)
	end
end

MenuItem.render = function (self, dt, t, gui)
	if self._floating_tooltip then
		local layout_settings = MenuHelper:layout_settings(self.config.floating_tooltip.layout_settings)

		self._floating_tooltip:render(dt, t, gui, layout_settings)
	end
end

MenuItem.destroy = function (self)
	if self.__destroyed then
		return
	end

	self.__destroyed = true

	if self.config.page then
		self.config.page:destroy()
	end
end
