-- chunkname: @scripts/menu/menu_containers/menu_container.lua

MenuContainer = class(MenuContainer)

MenuContainer.init = function (self)
	self._width = 0
	self._height = 0
	self._x = 0
	self._y = 0
end

MenuContainer.width = function (self)
	return self._width
end

MenuContainer.height = function (self)
	return self._height
end

MenuContainer.x = function (self)
	return self._x
end

MenuContainer.y = function (self)
	return self._y
end

MenuContainer.z = function (self)
	return self._z
end

MenuContainer.destroy = function (self)
	return
end
