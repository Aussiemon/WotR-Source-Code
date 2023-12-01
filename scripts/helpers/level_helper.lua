-- chunkname: @scripts/helpers/level_helper.lua

LevelHelper = LevelHelper or {}

LevelHelper.current_level_settings = function (self)
	local level_key = Managers.state.game_mode:level_key()

	return LevelSettings[level_key]
end

LevelHelper.current_level = function (self, world)
	local level_settings = self:current_level_settings()
	local level = ScriptWorld.level(world, level_settings.level_name)

	return level
end
