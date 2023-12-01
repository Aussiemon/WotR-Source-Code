-- chunkname: @scripts/menu/menu_containers/rect_menu_container.lua

require("scripts/menu/menu_containers/menu_container")

RectMenuContainer = class(RectMenuContainer, MenuContainer)

RectMenuContainer.init = function (self)
	RectMenuContainer.super.init(self)
end

RectMenuContainer.update_size = function (self, dt, t, gui, layout_settings)
	local res_width, res_height = Gui.resolution()

	self._width = layout_settings.absolute_width or layout_settings.width * res_width
	self._height = layout_settings.absolute_height or layout_settings.height * res_height
end

RectMenuContainer.update_position = function (self, dt, t, layout_settings, x, y, z)
	self._x = x
	self._y = y
	self._z = z
end

RectMenuContainer.render = function (self, dt, t, gui, layout_settings)
	local color = Color(layout_settings.color[1], layout_settings.color[2], layout_settings.color[3], layout_settings.color[4])

	Gui.rect(gui, Vector3(math.floor(self._x), math.floor(self._y), self._z), Vector2(math.floor(self._width), math.floor(self._height)), color)

	if layout_settings.border_size then
		local x = self._x
		local y = self._y
		local z = self._z
		local w = self._width
		local h = self._height
		local color = Color(layout_settings.border_color[1], layout_settings.border_color[2], layout_settings.border_color[3], layout_settings.border_color[4])

		Gui.rect(gui, Vector3(x - layout_settings.border_size, y + h, z + 1), Vector2(w + layout_settings.border_size * 2, layout_settings.border_size), color)
		Gui.rect(gui, Vector3(x - layout_settings.border_size, y - layout_settings.border_size, z + 1), Vector2(w + layout_settings.border_size * 2, layout_settings.border_size), color)
		Gui.rect(gui, Vector3(x - layout_settings.border_size, y, z + 1), Vector2(layout_settings.border_size, h), color)
		Gui.rect(gui, Vector3(x + w, y, z + 1), Vector2(layout_settings.border_size, h), color)
	end
end

RectMenuContainer.create_from_config = function ()
	return RectMenuContainer:new()
end
