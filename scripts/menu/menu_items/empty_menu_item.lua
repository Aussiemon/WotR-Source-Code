-- chunkname: @scripts/menu/menu_items/empty_menu_item.lua

EmptyMenuItem = class(EmptyMenuItem, MenuItem)

EmptyMenuItem.init = function (self, config, world)
	EmptyMenuItem.super.init(self, config, world)
end

EmptyMenuItem.update_size = function (self)
	if self.config.relative_height then
		local _, res_height = Gui.resolution()

		self._height = self.config.relative_height * res_height
	end
end

EmptyMenuItem.update_position = function (self, dt, t, layout_settings, x, y, z)
	self._x = x
	self._y = y
	self._z = z
end

EmptyMenuItem.render = function (self)
	return
end

EmptyMenuItem.render_from_child_page = function (self)
	return
end

EmptyMenuItem.create_from_config = function (compiler_data, config, callback_object)
	local config = {
		disabled = true,
		type = "empty",
		name = config.name,
		page = config.page,
		layout_settings = config.layout_settings,
		relative_height = config.relative_height
	}

	return EmptyMenuItem:new(config, compiler_data.world)
end
