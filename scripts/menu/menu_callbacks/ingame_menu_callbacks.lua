-- chunkname: @scripts/menu/menu_callbacks/ingame_menu_callbacks.lua

IngameMenuCallbacks = class(IngameMenuCallbacks)

IngameMenuCallbacks.init = function (self, game_state)
	self._game_state = game_state
end

IngameMenuCallbacks.cb_leave_game = function (self)
	if not EDITOR_LAUNCH then
		self._game_state.parent.exit_to_menu = true

		self._game_state:ingame_menu():set_active(false)
	end
end

IngameMenuCallbacks.cb_return_to_battle = function (self)
	self._game_state:ingame_menu():set_active(false)
end

local SOUND_MIN = -60
local SOUND_MAX = 0
local SOUND_0 = -100
local SOUND_KEY_EPSILON = 0.1

SoundHelper = SoundHelper or {}

SoundHelper.calculate_volume = function (volume_setting)
	local dB

	if volume_setting == 0 then
		dB = SOUND_0
	else
		dB = math.lerp(SOUND_MIN, SOUND_MAX, (volume_setting - 1) / 9)
	end

	return dB
end

SoundHelper.sound_volume_options = function (bus_name)
	local options = {}
	local saved_option = Application.user_setting(bus_name)
	local selected_index = 2

	for i = 0, 10 do
		local key = SoundHelper.calculate_volume(10 - i)

		options[#options + 1] = {
			key = key,
			value = (10 - i) * 10
		}

		if saved_option and math.abs(saved_option - key) < SOUND_KEY_EPSILON then
			selected_index = i + 1
		end
	end

	return options, selected_index
end

IngameMenuCallbacks.cb_master_volumes = function (self)
	local options, index = SoundHelper.sound_volume_options("master_volume")

	return options, index
end

IngameMenuCallbacks.cb_master_volume_changed = function (self, option)
	Application.set_user_setting("master_volume", option.key)
	Application.save_user_settings()
	Timpani.set_bus_volume("Master Bus", option.key)
end

IngameMenuCallbacks.cb_voice_over_volume_changed = function (self, option)
	Application.set_user_setting("voice_over", option.key)
	Application.save_user_settings()
	Timpani.set_bus_volume("voice_over", option.key)
end

IngameMenuCallbacks.cb_voice_over_volumes = function (self)
	local options, index = SoundHelper.sound_volume_options("voice_over")

	return options, index
end

IngameMenuCallbacks.cb_music_volumes = function (self)
	local options, index = SoundHelper.sound_volume_options("music_volume")

	return options, index
end

IngameMenuCallbacks.cb_music_volume_changed = function (self, option)
	Application.set_user_setting("music_volume", option.key)
	Application.save_user_settings()
	Timpani.set_bus_volume("music", option.key)
end

IngameMenuCallbacks.cb_sfx_volumes = function (self)
	local options, index = SoundHelper.sound_volume_options("sfx_volume")

	return options, index
end

IngameMenuCallbacks.cb_sfx_volume_changed = function (self, option)
	Application.set_user_setting("sfx_volume", option.key)
	Application.save_user_settings()
	Timpani.set_bus_volume("sfx", option.key)
	Timpani.set_bus_volume("special", option.key)
end

IngameMenuCallbacks.cb_profile_viewer_world_name = function (self)
	return "level_world"
end

IngameMenuCallbacks.cb_profile_viewer_viewport_name = function (self, local_player)
	return local_player.viewport_name
end

IngameMenuCallbacks.cb_outfit_editor_highlight_item = function (self)
	return "goto_select_team_button"
end

IngameMenuCallbacks.cb_goto_select_team_disabled = function (self)
	return Managers.time:time("round") < GameSettingsDevelopment.exit_ingame_character_editor_round_time
end

IngameMenuCallbacks.cb_team_selection_highlight_item = function (self)
	local controller_active = Managers.input:pad_active(1)

	if controller_active then
		return nil
	else
		return "auto_join_team_button"
	end
end

IngameMenuCallbacks.cb_goto_outfit_editor_disabled = function (self)
	return Managers.time:time("round") >= 0
end

IngameMenuCallbacks.cb_character_profiles_options = function (self)
	local options = {}

	for i, config in ipairs(PlayerProfiles) do
		options[#options + 1] = {
			key = i,
			value = config.display_name
		}
	end

	return options
end

IngameMenuCallbacks.cb_character_profiles_option_changed = function (self, spawn_profile)
	self._game_state.player.state_data.spawn_profile = spawn_profile

	self._game_state:ingame_menu():goto("select_spawnpoint")
end

IngameMenuCallbacks.cb_character_profile_highlight_item = function (self)
	return "select_spawnpoint_button"
end

IngameMenuCallbacks.cb_character_profile_selected_option = function (self)
	return self._game_state.player.state_data.spawn_profile or Application.win32_user_setting("character_selection_profile") or 1
end

IngameMenuCallbacks.cb_select_character_cancelled = function (self)
	if self._game_state.player.state_data.spawn_profile then
		self._game_state:ingame_menu():goto("select_spawnpoint")
	else
		self._game_state:ingame_menu():goto("select_team")
	end
end

IngameMenuCallbacks.cb_select_character_ingame_cancelled = function (self)
	self._game_state:ingame_menu():goto("select_spawnpoint_ingame")
end

IngameMenuCallbacks.cb_goto_select_spawnpoint_disabled = function (self)
	return not self._game_state.player.state_data.spawn_profile
end

IngameMenuCallbacks.cb_select_spawnpoint_highlight_item = function (self)
	return "spawn_button"
end

IngameMenuCallbacks.cb_select_spawnpoint_disabled = function (self)
	local state = self._game_state.player.spawn_data.state

	return state ~= "dead" and state ~= "not_spawned" and state ~= "ghost_mode"
end

IngameMenuCallbacks.cb_pre_spawn_ingame_menu_highlight_item = function (self)
	return "back_to_select_spawnpoint"
end

IngameMenuCallbacks.cb_game_data = function (self)
	local loading_context = self._game_state.parent.loading_context
	local data = {
		level = Managers.state.game_mode:level_key(),
		game_mode = Managers.state.game_mode:game_mode_key(),
		spawn_profile = self._game_state.player.state_data.spawn_profile
	}

	return data
end

IngameMenuCallbacks.cb_goto = function (self, page_id)
	self._game_state:ingame_menu():goto(page_id)
end

IngameMenuCallbacks.cb_cancel_to = function (self, page_id)
	self._game_state:ingame_menu_cancel_to(page_id)
end

IngameMenuCallbacks.cb_leave_game_popup_item_selected = function (self, args)
	if args.action == "leave_game" then
		self:cb_leave_game()
	end
end

IngameMenuCallbacks.cb_alignment_dummy_units = function (self)
	return {}
end

IngameMenuCallbacks.cb_controller_enabled = function (self)
	return Managers.input:pad_active(1)
end

IngameMenuCallbacks.cb_controller_disabled = function (self)
	return not Managers.input:pad_active(1)
end

IngameMenuCallbacks.cb_ingame_select_spawnpoint_visible = function (self)
	return Managers.state.network:game()
end

IngameMenuCallbacks.cb_voice_overs = function (self)
	local options = {
		{
			key = "normal",
			value = L("main_menu_voice_over_normal")
		}
	}

	if DLCSettings.brian_blessed() then
		options[#options + 1] = {
			key = "brian_blessed",
			value = L("main_menu_voice_over_brian_blessed")
		}
	end

	return options, HUDSettings.announcement_voice_over == "normal" and 1 or 2
end

IngameMenuCallbacks.cb_voice_over_changed = function (self, option)
	HUDSettings.announcement_voice_over = option.key

	Application.set_user_setting("announcement_voice_over", option.key)
	Application.save_user_settings()
end
