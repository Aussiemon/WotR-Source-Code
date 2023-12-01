-- chunkname: @scripts/menu/menu_containers/outfit_list_menu_container.lua

require("scripts/menu/menu_containers/item_list_menu_container")

OutfitListMenuContainer = class(OutfitListMenuContainer, ItemListMenuContainer)

OutfitListMenuContainer.init = function (self, items)
	OutfitListMenuContainer.super.init(self, items)
end

OutfitListMenuContainer.load_profile = function (self, player_profile)
	for i, item in ipairs(self._items) do
		item:load_profile(player_profile)
	end
end

OutfitListMenuContainer.create_from_config = function (items)
	return OutfitListMenuContainer:new(items)
end
