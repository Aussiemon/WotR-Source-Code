﻿-- chunkname: @scripts/settings/game_settings_development.lua

GameSettingsDevelopment = GameSettingsDevelopment or {}

local argv = {
	Application.argv()
}

UNLOCK_DLC = 230940
IS_DEMO = false
GameSettingsDevelopment.default_environment = "core/rendering/default_outdoor"
GameSettingsDevelopment.default_time_limit = 500000
GameSettingsDevelopment.default_win_score = 100
GameSettingsDevelopment.buy_game_url = "http://www.waroftherosesthegame.com/buy"
GameSettingsDevelopment.twitter_url = "http://twitter.com/AWarofRoses"
GameSettingsDevelopment.facebook_url = "http://www.facebook.com/AWarofRoses"
GameSettingsDevelopment.survey_url = "http://goo.gl/V4qXU"
GameSettingsDevelopment.quicklaunch_params = GameSettingsDevelopment.quicklaunch_params or {}
GameSettingsDevelopment.quicklaunch_params.level_key = EDITOR_LAUNCH and "editor_level" or "castle_01"
GameSettingsDevelopment.quicklaunch_params.game_mode_key = "tdm"
GameSettingsDevelopment.quicklaunch_params.number_players = EDITOR_LAUNCH and 1 or 1
GameSettingsDevelopment.quicklaunch_params.spawn_clones = nil
GameSettingsDevelopment.start_state = EDITOR_LAUNCH and "game" or "menu"
GameSettingsDevelopment.disable_singleplayer = false
GameSettingsDevelopment.disable_coat_of_arms_editor = false
GameSettingsDevelopment.disable_character_sheet = false
GameSettingsDevelopment.disable_key_mappings = false
GameSettingsDevelopment.disable_uniform_lod = false
GameSettingsDevelopment.allow_old_join_game = true
GameSettingsDevelopment.network_timeout = 10
GameSettingsDevelopment.show_version_info = true
GameSettingsDevelopment.show_nda_in_splash_screen = false
GameSettingsDevelopment.server_license_check = true
GameSettingsDevelopment.enable_robot_player = false
GameSettingsDevelopment.all_on_same_team = false
GameSettingsDevelopment.allow_multiple_dot_effects = false
GameSettingsDevelopment.backend_timeout = 90

if table.find(argv, "-eac") then
	GameSettingsDevelopment.anti_cheat_enabled = true
else
	GameSettingsDevelopment.anti_cheat_enabled = false
end

if script_data.settings.dedicated_server then
	GameSettingsDevelopment.network_mode = "steam"
elseif script_data.settings.content_revision then
	GameSettingsDevelopment.network_mode = "steam"

	if rawget(_G, "Steam") then
		if Steam.app_id() == 42160 then
			GameSettingsDevelopment.enable_micro_transactions = true
			GameSettingsDevelopment.allow_host_game = false
			GameSettingsDevelopment.allow_host_practice = false
			GameSettingsDevelopment.unlock_all = false
			GameSettingsDevelopment.show_fps = Application.user_setting("show_fps") or false
			GameSettingsDevelopment.hide_lan_tab = true
			GameSettingsDevelopment.disable_singleplayer = false
			GameSettingsDevelopment.disable_coat_of_arms_editor = false
			GameSettingsDevelopment.disable_character_sheet = true
			GameSettingsDevelopment.disable_key_mappings = false
			GameSettingsDevelopment.disable_uniform_lod = not script_data.settings.uniform_lod
			GameSettingsDevelopment.allow_old_join_game = false
			GameSettingsDevelopment.show_version_info = false
			GameSettingsDevelopment.backend_address = "ftdata.fatshark.se"
		elseif Steam.app_id() == 203030 then
			DLCSettings.full_game = function ()
				return true
			end

			GameSettingsDevelopment.allow_host_game = false
			GameSettingsDevelopment.allow_host_practice = true
			GameSettingsDevelopment.unlock_all = false
			GameSettingsDevelopment.show_fps = Application.user_setting("show_fps") or false
			GameSettingsDevelopment.hide_lan_tab = true
			GameSettingsDevelopment.disable_singleplayer = false
			GameSettingsDevelopment.disable_coat_of_arms_editor = false
			GameSettingsDevelopment.disable_character_sheet = true
			GameSettingsDevelopment.disable_key_mappings = false
			GameSettingsDevelopment.disable_uniform_lod = not script_data.settings.uniform_lod
			GameSettingsDevelopment.allow_old_join_game = false
			GameSettingsDevelopment.show_version_info = false
			GameSettingsDevelopment.backend_address = "fttest01.fatshark.se"
		elseif Steam.app_id() == 203790 then
			DLCSettings.full_game = function ()
				return true
			end

			GameSettingsDevelopment.enable_micro_transactions = false
			GameSettingsDevelopment.allow_host_game = false
			GameSettingsDevelopment.allow_host_practice = false
			GameSettingsDevelopment.unlock_all = false
			GameSettingsDevelopment.show_fps = false
			GameSettingsDevelopment.hide_lan_tab = true
			GameSettingsDevelopment.disable_character_sheet = true
			GameSettingsDevelopment.all_on_same_team = true
			GameSettingsDevelopment.allow_old_join_game = false
			GameSettingsDevelopment.disable_uniform_lod = not script_data.settings.uniform_lod
			GameSettingsDevelopment.backend_address = "fttest01.fatshark.se"
		elseif Steam.app_id() == 206980 then
			DLCSettings.full_game = function ()
				return true
			end

			GameSettingsDevelopment.allow_host_game = false
			GameSettingsDevelopment.allow_host_practice = true
			GameSettingsDevelopment.unlock_all = false
			GameSettingsDevelopment.show_fps = Application.user_setting("show_fps") or false
			GameSettingsDevelopment.hide_lan_tab = true
			GameSettingsDevelopment.disable_singleplayer = false
			GameSettingsDevelopment.disable_coat_of_arms_editor = false
			GameSettingsDevelopment.disable_character_sheet = true
			GameSettingsDevelopment.disable_key_mappings = false
			GameSettingsDevelopment.disable_uniform_lod = not script_data.settings.uniform_lod
			GameSettingsDevelopment.allow_old_join_game = false
			GameSettingsDevelopment.show_version_info = false
			GameSettingsDevelopment.backend_address = "fttest01.fatshark.se"
		else
			DLCSettings.full_game = function ()
				return true
			end

			GameSettingsDevelopment.enable_micro_transactions = false
			GameSettingsDevelopment.allow_host_game = false
			GameSettingsDevelopment.allow_host_practice = false
			GameSettingsDevelopment.unlock_all = false
			GameSettingsDevelopment.show_fps = Application.user_setting("show_fps") or false
			GameSettingsDevelopment.hide_lan_tab = true
			GameSettingsDevelopment.disable_singleplayer = false
			GameSettingsDevelopment.disable_coat_of_arms_editor = false
			GameSettingsDevelopment.disable_character_sheet = true
			GameSettingsDevelopment.disable_key_mappings = false
			GameSettingsDevelopment.disable_uniform_lod = not script_data.settings.uniform_lod
			GameSettingsDevelopment.allow_old_join_game = false
			GameSettingsDevelopment.backend_address = "fttest01.fatshark.se"
		end
	end
elseif Application.build() == "dev" or Application.build() == "debug" then
	GameSettingsDevelopment.disable_full_game_licence_check = true

	DLCSettings.full_game = function ()
		return true
	end

	GameSettingsDevelopment.network_mode = EDITOR_LAUNCH and "lan" or table.find(argv, "-force-steam") and "steam" or "lan"
	GameSettingsDevelopment.unlock_all = true
	GameSettingsDevelopment.all_on_same_team = true
	GameSettingsDevelopment.allow_host_game = true
	GameSettingsDevelopment.allow_host_practice = true
	GameSettingsDevelopment.show_fps = true
	GameSettingsDevelopment.enable_micro_transactions = false
	GameSettingsDevelopment.backend_address = "fttest.fatshark.se"
else
	print("Running release game without content revision, quitting.")
	Application.quit()
end

GameSettingsDevelopment.network_port = 10000
GameSettingsDevelopment.network_revision_check_enabled = true
GameSettingsDevelopment.disable_loading_screen_menu = EDITOR_LAUNCH and true or false
GameSettingsDevelopment.loading_screen_minimum_show_time = 5
GameSettingsDevelopment.exit_ingame_character_editor_round_time = -10
GameSettingsDevelopment.disable_character_profiles_editor = false
GameSettingsDevelopment.game_start_countdown = 1
GameSettingsDevelopment.prototype_spawn_fallback = false
GameSettingsDevelopment.lowest_resolution = 1024
GameSettingsDevelopment.physics_cull_husks = GameSettingsDevelopment.physics_cull_husks or {}
GameSettingsDevelopment.physics_cull_husks.cull_range = 18
GameSettingsDevelopment.physics_cull_husks.uncull_range = 10
GameSettingsDevelopment.bone_lod_husks = GameSettingsDevelopment.bone_lod_husks or {}
GameSettingsDevelopment.bone_lod_husks.lod_out_range = 15
GameSettingsDevelopment.bone_lod_husks.lod_in_range = 15
GameSettingsDevelopment.bone_lod_ais = GameSettingsDevelopment.bone_lod_ais or {}
GameSettingsDevelopment.bone_lod_ais.lod_out_range = 15
GameSettingsDevelopment.bone_lod_ais.lod_in_range = 15
GameSettingsDevelopment.min_team_size_to_save_stats = 1
GameSettingsDevelopment.backend_save_timeout = 5
GameSettingsDevelopment.allow_decapitation = true

if Application.build() == "release" then
	GameSettingsDevelopment.remove_debug_stuff = true
else
	GameSettingsDevelopment.remove_debug_stuff = false
end

script_data.extrapolation_debug = true

if script_data.settings.debug_mode then
	script_data.network_debug = true

	Network.log(Network.MESSAGES)
end

GameSettingsDevelopment.performance_profiling = GameSettingsDevelopment.performance_profiling or {}
GameSettingsDevelopment.performance_profiling.active = false
GameSettingsDevelopment.performance_profiling.frames_between_print = 10

function remove_debug_stuff()
	Commands.script = function ()
		return
	end

	Commands.console = function ()
		return
	end

	Managers.free_flight.update = function ()
		return
	end

	Commands.game_speed = function ()
		return
	end

	Commands.fov = function ()
		return
	end

	Commands.free_flight_settings = function ()
		return
	end

	Commands.lag = function ()
		return
	end

	Commands.location = function ()
		return
	end

	Commands.next_level = function ()
		return
	end
end

function debug_unit_movement(unit, unit_name)
	if not script_data.core_debug_enabled then
		Application.set_autoload_enabled(true)
		require("core/debug/init")

		script_data.core_debug_enabled = true
	end

	local debug_horse_pos = Vector3Box()

	Profiler.record_statistics("horse_speed", 0)
	Profiler.record_statistics("horse_speed_components", Vector3(0, 0, 0))
	debug_horse_pos:store(Unit.local_position(script_data.horse_unit, 0))
	Core.Debug.add_updator(function (dt)
		local new_pos = Unit.local_position(unit, 0)
		local velocity = (new_pos - debug_horse_pos:unbox()) / dt
		local rot = Unit.local_rotation(unit, 0)
		local fwd_speed = Vector3.dot(velocity, Quaternion.forward(rot))
		local right_speed = Vector3.dot(velocity, Quaternion.right(rot))
		local up_speed = Vector3.dot(velocity, Quaternion.up(rot))

		Profiler.record_statistics(unit_name .. "_speed_components", Vector3(right_speed, fwd_speed, up_speed))
		Profiler.record_statistics(unit_name .. "_speed", Vector3.length(velocity))
		debug_horse_pos:store(new_pos)
	end)
end

function enable_physics_dump()
	local physics_namespaces = {
		"PhysicsWorld",
		"Actor",
		"Mover"
	}

	for _, namespace in pairs(physics_namespaces) do
		local namespace_to_debug = _G[namespace]

		for func_name, func in pairs(namespace_to_debug) do
			if type(func) == "function" then
				namespace_to_debug[func_name] = function (...)
					local output = string.format("%s.%s() : ", namespace, func_name)

					print(output, select(2, ...))

					return func(...)
				end
			end
		end
	end
end
