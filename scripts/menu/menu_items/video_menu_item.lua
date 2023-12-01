-- chunkname: @scripts/menu/menu_items/video_menu_item.lua

VideoMenuItem = class(VideoMenuItem, MenuItem)

VideoMenuItem.init = function (self, config, world)
	VideoMenuItem.super.init(self, config, world)
end

VideoMenuItem.on_page_enter = function (self)
	VideoMenuItem.super.on_page_enter(self)

	self._first_frame = true
end

VideoMenuItem.on_page_exit = function (self)
	VideoMenuItem.super.on_page_exit(self)
	self:_stop_sound()
end

VideoMenuItem.destroy = function (self)
	VideoMenuItem.super.destroy(self)

	if self._video_player then
		World.destroy_video_player(self._world, self._video_player)

		self._video_player = nil
	end

	self:_stop_sound()
end

VideoMenuItem._stop_sound = function (self)
	if self._sound then
		local timpani_world = World.timpani_world(self._world)

		TimpaniWorld.stop(timpani_world, self._sound)

		self._sound = nil
	end
end

VideoMenuItem.update_size = function (self, dt, t, gui, layout_settings)
	local w, h

	if layout_settings.fullscreen then
		w, h = MenuHelper.scale_to_fullscren(layout_settings.video_width, layout_settings.video_height, true)
	else
		w = layout_settings.width
		h = layout_settings.height
	end

	self._width = w
	self._height = h
end

VideoMenuItem.update_position = function (self, dt, t, layout_settings, x, y, z)
	self._x = x
	self._y = y
	self._z = z
end

VideoMenuItem.render = function (self, dt, t, gui, layout_settings)
	local color = Color(255, 255, 255, 255)

	if self._first_frame and t < 0.75 then
		return
	elseif self._first_frame then
		color = Color(255, 0, 0, 0)
		self._first_frame = false

		local layout_settings = HUDHelper:layout_settings(self.config.layout_settings)
		local ivf = layout_settings.video and layout_settings.video.ivf or self.config.video.ivf

		self._video_player = World.create_video_player(self._world, ivf, layout_settings.loop)

		local sound_event = layout_settings.video and layout_settings.video.sound_event or self.config.video and self.config.video.sound_event or nil

		if sound_event then
			local timpani_world = World.timpani_world(self._world)

			self._sound = TimpaniWorld.trigger_event(timpani_world, sound_event)
		end
	else
		local c = math.min((t - 0.75) * 0.5, 1) * 255

		color = Color(c, 255, 255, 255)
	end

	local player = self._video_player
	local video = layout_settings.video and layout_settings.video.video or self.config.video.video

	Gui.video(gui, video, player, Vector3(self._x, self._y, self._z), Vector2(self._width, self._height), color)

	if VideoPlayer.current_frame(player) == VideoPlayer.number_of_frames(player) then
		self:_try_callback(self.config.callback_object, self.config.on_video_end, unpack(self.config.on_video_end_args or {}))
	end
end

VideoMenuItem.create_from_config = function (compiler_data, config, callback_object)
	local config = {
		type = "text_input",
		page = config.page,
		name = config.name,
		disabled = config.disabled,
		disabled_func = config.disabled_func and callback(callback_object, config.disabled_func, config.disabled_func_args),
		on_video_end = config.on_video_end,
		on_video_end_args = config.on_video_end_args or {},
		callback_object = callback_object,
		layout_settings = config.layout_settings,
		parent_page = config.parent_page,
		sounds = config.parent_page.config.sounds.items.text_input,
		video = config.video,
		sound_event = config.sound_event
	}

	return VideoMenuItem:new(config, compiler_data.world)
end
