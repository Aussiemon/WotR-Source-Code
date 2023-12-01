-- chunkname: @scripts/managers/admin/server_stats_printer.lua

ServerStatsPrinter = class(ServerStatsPrinter)

local PRINT_FREQUENCY = 30

ServerStatsPrinter.init = function (self)
	self._timer = 0
	self._game_time = 0
end

ServerStatsPrinter.update = function (self, dt, t)
	self._timer = self._timer + dt

	if self._timer >= PRINT_FREQUENCY then
		self:_print_stats(dt, t)

		self._timer = 0
	end

	local player_count = table.size(Managers.player:players())

	self._game_time = self._game_time + player_count * dt
end

ServerStatsPrinter._print_stats = function (self, dt, t)
	CommandWindow.print("[Stats]", "FPS = ", math.round(1 / dt, 2), "Players = ", table.size(Managers.player:players()), "Game Time = ", math.round(self._game_time, 2))
end
