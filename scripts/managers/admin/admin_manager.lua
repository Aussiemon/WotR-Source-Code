-- chunkname: @scripts/managers/admin/admin_manager.lua

require("scripts/managers/admin/auto_rules")
require("scripts/managers/admin/auto_balancer")
require("scripts/managers/admin/server_stats_printer")
require("scripts/managers/admin/network_performance_rules")
require("scripts/managers/admin/script_rcon_server")
require("scripts/managers/admin/speed_hack_detector")
require("scripts/managers/game_mode/spawn_modes/pulse_spawning")
require("scripts/managers/game_mode/spawn_modes/personal_spawning")
require("scripts/managers/admin/script_anti_cheat")

local KICK_TIMEOUT = 3
local RCON_ADMIN_TIME = 300

AdminManager = class(AdminManager)

AdminManager.init = function (self, settings)
	self._settings = settings
	self._server_locked = false

	self:_setup_spawning(settings.spawning)
	self:_setup_friendly_fire(settings)
	self:_setup_max_squad_size(settings)
	self:_setup_reserved_slots(settings)

	self._auto_rules = AutoRules:new(settings)
	self._auto_balancer = AutoBalancer:new(settings.auto_balance)
	self._server_stats_printer = ServerStatsPrinter:new()
	self._network_performance_rules = NetworkPerformanceRules:new(settings)
	self._rcon_server = ScriptRconServer:new(settings.rcon)
	settings.anti_cheat = settings.anti_cheat or {}
	self._speed_hack_detector = SpeedHackDetector:new(settings.anti_cheat.speedhack)
	self._anti_cheat = ScriptAntiCheat:new(settings.anti_cheat)
	self._kick_list = {}
end

AdminManager.register_peer = function (self, network_id, anti_cheat_key)
	self._anti_cheat:register_peer(network_id, anti_cheat_key)
end

AdminManager.unregister_peer = function (self, network_id)
	self._anti_cheat:unregister_peer(network_id)
end

AdminManager.settings = function (self)
	return self._settings
end

AdminManager.setup = function (self)
	self._auto_rules:setup()
	self._auto_balancer:setup()
	self._speed_hack_detector:setup()
end

AdminManager._setup_spawning = function (self, settings)
	self._spawning_settings = settings
end

AdminManager._setup_friendly_fire = function (self, settings)
	if settings.friendly_fire then
		local melee = settings.friendly_fire.melee or {}
		local ranged = settings.friendly_fire.ranged or {}

		self:set_friendly_fire(melee.value, melee.mirror, ranged.value, ranged.mirror)
	end
end

AdminManager._setup_max_squad_size = function (self, settings)
	local max_squad_size = settings.server_init_settings.max_squad_size or 8

	TeamSettings.red.max_squad_members = math.clamp(max_squad_size, 0, math.huge)
	TeamSettings.white.max_squad_members = math.clamp(max_squad_size, 0, math.huge)
end

AdminManager._setup_reserved_slots = function (self, settings)
	local num_reserved_slots = table.size(Application.user_setting("reserved_slots") or {})

	settings.server_init_settings.max_players = settings.server_init_settings.max_players + num_reserved_slots
end

AdminManager.spawning = function (self)
	return self._spawning_settings
end

AdminManager.update = function (self, dt, t)
	Profiler.start("AdminManager")
	self._auto_rules:update(dt, t)
	self._auto_balancer:update(dt, t)
	self._server_stats_printer:update(dt, t)
	self._network_performance_rules:update(dt, t)
	self._rcon_server:update(dt, t)
	self:_update_kick_list(dt, t)
	self:_update_rcon_admin(dt, t)
	self._anti_cheat:update(dt, Managers.time:time("main"))
	Profiler.stop()
end

AdminManager.kick_player = function (self, peer_id, reason)
	local kick_list = self._kick_list

	if kick_list[peer_id] then
		return
	end

	kick_list[peer_id] = KICK_TIMEOUT + Managers.time:time("game")

	RPC.rpc_kicked(peer_id, reason)
end

AdminManager._update_kick_list = function (self, dt, t)
	local kick_list = self._kick_list

	for peer_id, kick_time in pairs(kick_list) do
		if kick_time <= t then
			Managers.lobby:kick_member(peer_id)

			kick_list[peer_id] = nil
		end
	end
end

AdminManager._update_rcon_admin = function (self, dt, t)
	if self._rcon_admin and t >= self._rcon_admin_time and Managers.state.network:game() then
		local player = Managers.state.network:player_from_peer_id(self._rcon_admin)

		if player then
			RPC.rpc_rcon_logged_out(self._rcon_admin, player:player_id())
			RPC.rpc_rcon_reply(self._rcon_admin, "You have been logged out from RCON")
		end

		self:set_rcon_admin(nil)
	end
end

AdminManager.is_player_banned = function (self, peer_id)
	local ban = Application.user_setting("banned_players", peer_id)
	local time = os.time(os.date("*t"))

	if ban then
		if type(ban) == "string" then
			local ban_string = string.split(ban, ":")
			local ban_time = tonumber(ban_string[1])
			local reason = ban_string[2]

			if ban_time and (time < ban_time or ban_time == -1) then
				return true
			else
				Application.set_user_setting("banned_players", peer_id, nil)
				Application.save_user_settings()

				return false
			end
		else
			return true
		end
	else
		return false
	end
end

AdminManager.ban_player = function (self, peer_id, reason, duration)
	local name

	for _, player in pairs(Managers.player:players()) do
		if player:network_id() == peer_id then
			name = player:name()

			break
		end
	end

	local time = -1

	if duration then
		time = os.time(os.date("*t")) + duration
	end

	Application.set_user_setting("banned_players", peer_id, time .. ":" .. reason)

	if name then
		Application.set_user_setting("banned_player_names", name, peer_id)
	end

	Application.save_user_settings()
	self:kick_player(peer_id, reason or "BANNED")
end

AdminManager.unban_player = function (self, peer_id_or_name)
	local banned_by_id = Application.user_setting("banned_players", peer_id_or_name)
	local banned_by_name = Application.user_setting("banned_player_names", peer_id_or_name)
	local ban

	if not banned_by_id then
		ban = Application.user_setting("banned_players", banned_by_name)
	else
		ban = banned_by_id
	end

	if ban then
		if not banned_by_id and banned_by_name then
			Application.set_user_setting("banned_player_names", peer_id_or_name, nil)
			Application.set_user_setting("banned_players", banned_by_name, nil)
		else
			Application.set_user_setting("banned_players", peer_id_or_name, nil)
		end

		Application.save_user_settings()
	else
		return peer_id_or_name
	end
end

AdminManager.set_friendly_fire = function (self, melee_value, melee_mirror, ranged_value, ranged_mirror)
	if melee_value ~= nil then
		AttackDamageRangeTypes.melee.friendly_fire_multiplier = math.clamp(tonumber(melee_value), 0, 1)
	end

	if melee_mirror ~= nil then
		AttackDamageRangeTypes.melee.mirrored = to_boolean(melee_mirror)
	end

	if ranged_value ~= nil then
		AttackDamageRangeTypes.small_projectile.friendly_fire_multiplier = math.clamp(tonumber(ranged_value), 0, 1)
	end

	if ranged_mirror ~= nil then
		AttackDamageRangeTypes.small_projectile.mirrored = to_boolean(ranged_mirror)
	end

	return AttackDamageRangeTypes.melee.friendly_fire_multiplier, AttackDamageRangeTypes.melee.mirrored, AttackDamageRangeTypes.small_projectile.friendly_fire_multiplier, AttackDamageRangeTypes.small_projectile.mirrored
end

AdminManager.set_max_squad_size = function (self, max_squad_size)
	TeamSettings.red.max_squad_size = math.clamp(max_squad_size, 0, math.huge)
	TeamSettings.white.max_squad_size = math.clamp(max_squad_size, 0, math.huge)

	Managers.state.team:team_by_name("red"):set_max_squad_size(max_squad_size)
	Managers.state.team:team_by_name("white"):set_max_squad_size(max_squad_size)
	Managers.state.network:send_rpc_clients("rpc_set_max_squad_size", max_squad_size)
end

AdminManager.lock_server = function (self)
	self._server_locked = true
end

AdminManager.unlock_server = function (self)
	self._server_locked = false
end

AdminManager.is_server_locked = function (self)
	return self._server_locked
end

AdminManager.is_server_password_protected = function (self)
	local password = self._settings.server_init_settings.password

	return password and password ~= ""
end

AdminManager.map_rotation_settings = function (self, level_name, game_mode)
	for _, settings in pairs(self._settings.map_rotation.maps) do
		if settings.level == level_name and settings.game_mode == game_mode then
			return settings
		end
	end
end

AdminManager.is_demo_player_allowed = function (self, game_mode_key)
	return DemoSettings.available_game_modes[game_mode_key] and not self._settings.kick_demo_users
end

AdminManager.kill_player = function (self, peer_id)
	local player = Managers.player:player_from_network_id(peer_id)

	if Unit.alive(player.player_unit) then
		ScriptUnit.extension(player.player_unit, "damage_system"):die()
	end
end

AdminManager.add_reserved_slot = function (self, peer_id)
	local reserved_slots = Application.user_setting("reserved_slots") or {}

	if table.contains(reserved_slots, peer_id) then
		return false
	end

	reserved_slots[#reserved_slots + 1] = peer_id

	Application.set_user_setting("reserved_slots", reserved_slots)
	Application.save_user_settings()
	self:_setup_reserved_slots(self._settings)

	return true
end

AdminManager.remove_reserved_slot = function (self, peer_id)
	local reserved_slots = Application.user_setting("reserved_slots") or {}
	local key = table.find(reserved_slots, peer_id)

	if not key then
		return false
	end

	table.remove(reserved_slots, key)
	Application.set_user_setting("reserved_slots", reserved_slots)
	Application.save_user_settings()
	self:_setup_reserved_slots(self._settings)

	return true
end

AdminManager.check_reserved_slots = function (self, peer_id)
	local players = table.size(Managers.player:players())
	local reserved_slots = Application.user_setting("reserved_slots") or {}
	local num_reserved_slots = table.size(reserved_slots)
	local max_players_without_reserved_slots = self._settings.server_init_settings.max_players - num_reserved_slots

	if players < max_players_without_reserved_slots then
		return true
	end

	return table.contains(reserved_slots, peer_id)
end

AdminManager.set_rcon_admin = function (self, peer_id)
	self._rcon_admin = peer_id
	self._rcon_admin_time = Managers.time:time("game") + RCON_ADMIN_TIME
end

AdminManager.rcon_admin = function (self)
	return self._rcon_admin
end
