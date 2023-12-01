-- chunkname: @foundation/scripts/boot/boot.lua

if not EDITOR_LAUNCH then
	EDITOR_LAUNCH = false
end

local ProfilerScopes = {}

if not PROFILER_SCOPES_INITED then
	PROFILER_SCOPES_INITED = true

	local profiler_start = Profiler.start

	Profiler.start = function (scope_name)
		ProfilerScopes[scope_name] = true

		profiler_start(scope_name)
	end
end

function project_setup()
	return
end

function pre_update()
	return
end

local function base_require(path, ...)
	for _, s in ipairs({
		...
	}) do
		require(string.format("foundation/scripts/%s/%s", path, s))
	end
end

Boot = Boot or {}

Boot.setup = function (self)
	if Application.platform() == "win32" or Application.platform() == "macosx" then
		Window.set_focus()
		Window.set_mouse_focus(true)
	end

	self:_init_package_manager()
	self:_require_scripts()
	self:_init_managers()

	local start_state, params = project_setup()

	self:_setup_statemachine(start_state, params)
end

Boot._init_package_manager = function (self)
	base_require("managers", "managers", "package/package_manager")

	Managers.package = PackageManager

	Managers.package:init()
	Managers.package:load("foundation/resource_packages/boot")
end

Boot._require_scripts = function (self)
	Profiler.start("Boot:_require_scripts()")
	base_require("util", "error", "patches", "class", "callback", "rectangle", "state_machine", "misc_util", "stack", "table", "math", "vector3", "script_world", "script_viewport", "script_camera", "script_unit", "gui/gui_aux")
	base_require("input", "input_manager")
	base_require("entity_system", "entity_manager")
	base_require("managers", "world/world_manager", "player/player", "player/player_manager", "free_flight/free_flight_manager", "time/time_manager", "chat/chat_manager", "chat/chat_logger", "token/token_manager")
	Profiler.stop("Boot:_require_scripts()")
end

Boot._init_managers = function (self)
	Profiler.start("Boot:_init_managers()")

	Managers.time = TimeManager:new()
	Managers.world = WorldManager:new()
	Managers.free_flight = FreeFlightManager:new()
	Managers.player = PlayerManager:new()
	Managers.chat = ChatManager:new()
	Managers.token = TokenManager:new()

	Profiler.stop("Boot:_init_managers()")
end

Boot.pre_update = function (self, dt)
	return
end

Boot.update = function (self, dt)
	Managers.time:update(dt)

	local t = Managers.time:time("main")

	Profiler.start("LUA package update")
	Managers.package:update(dt, t)
	Profiler.stop()
	Profiler.start("LUA freeflight update")
	Managers.free_flight:update(dt, t)
	Profiler.stop()
	Profiler.start("LUA token update")
	Managers.token:update(dt, t)
	Profiler.stop()
	Profiler.start("LUA machine update")
	self._machine:update(dt, t)
	Profiler.stop()
	Profiler.start("LUA world update")
	Managers.world:update(dt, t)
	Profiler.stop()

	if self.quit_game then
		Application.quit()
	end

	if EDITOR_LAUNCH and Keyboard.pressed(Keyboard.button_index("f5")) then
		Application.console_send({
			type = "stop_testing"
		})
	end
end

Boot.post_update = function (self, dt)
	self._machine:post_update(dt)
end

Boot.render = function (self)
	Managers.world:render()
	self._machine:render()
end

Boot._setup_statemachine = function (self, start_state, params)
	Profiler.start("Boot:_setup_statemachine()")

	self._machine = StateMachine:new(self, start_state, params)

	Profiler.stop("Boot:_setup_statemachine()")
end

Boot.shutdown = function (self)
	self._machine:destroy()
	Managers:destroy()
end

function init()
	Boot:setup()
end

function update(dt)
	Profiler.start("LUA pre_update")
	pre_update(dt)
	Profiler.stop()
	Profiler.start("LUA update")
	Boot:update(dt)
	Profiler.stop()
	Profiler.start("LUA post_update")
	Boot:post_update(dt)
	Profiler.stop()
end

function render()
	Boot:render()
end

function shutdown()
	Boot:shutdown()
end
