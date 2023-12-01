-- chunkname: @scripts/menu/menus/final_scoreboard_menu.lua

require("scripts/menu/menus/menu")
require("scripts/menu/menu_controller_settings/final_scoreboard_menu_controller_settings")
require("scripts/menu/menu_definitions/final_scoreboard_menu_settings_1920")
require("scripts/menu/menu_definitions/final_scoreboard_menu_settings_1366")
require("scripts/menu/menu_definitions/final_scoreboard_menu_definition")
require("scripts/menu/menu_callbacks/final_scoreboard_menu_callbacks")

FinalScoreboardMenu = class(FinalScoreboardMenu, Menu)

FinalScoreboardMenu.init = function (self, game_state, world, data)
	FinalScoreboardMenu.super.init(self, game_state, world, FinalScoreboardMenuControllerSettings, FinalScoreboardMenuSettings, FinalScoreboardMenuDefinition, FinalScoreboardMenuCallbacks, data)
end

FinalScoreboardMenu.set_active = function (self, flag)
	FinalScoreboardMenu.super.set_active(self, flag)
	Managers.state.hud:set_active(not flag)
end
