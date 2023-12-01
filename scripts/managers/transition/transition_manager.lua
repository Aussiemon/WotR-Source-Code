-- chunkname: @scripts/managers/transition/transition_manager.lua

TransitionManager = class(TransitionManager)

TransitionManager.init = function (self)
	self:_setup_names()
	self:_setup_world()

	self._color = Vector3Box(0, 0, 0)
	self._fade_state = "out"
	self._fade = 0
end

TransitionManager._setup_names = function (self)
	self._world_name = "transition_world"
	self._viewport_name = "transition_viewport"
end

TransitionManager._setup_world = function (self)
	local world = Managers.world:create_world(self._world_name, GameSettingsDevelopment.default_environment, nil, 990, Application.DISABLE_SOUND, Application.DISABLE_PHYSICS)

	self._world = world
	self._gui = World.create_screen_gui(world, "immediate")

	local viewport = ScriptWorld.create_viewport(world, self._viewport_name, "overlay", 990)
	local camera = ScriptViewport.camera(viewport)

	Camera.set_vertical_fov(camera, 3)
end

TransitionManager.destroy = function (self)
	Managers.world:destroy_world(self._world_name)
end

TransitionManager.fade_in = function (self, speed, callback)
	self._fade_state = "fade_in"
	self._fade_speed = speed
	self._callback = callback
end

TransitionManager.fade_out = function (self, speed, callback)
	self._fade_state = "fade_out"
	self._fade_speed = -speed
	self._callback = callback
end

TransitionManager.force_fade_in = function (self)
	self._fade_state = "in"
	self._fade_speed = 0
	self._fade = 1

	if self._callback then
		self._callback()

		self._callback = nil
	end
end

TransitionManager.force_fade_out = function (self)
	self._fade_state = "out"
	self._fade_speed = 0
	self._fade = 0

	if self._callback then
		self._callback()

		self._callback = nil
	end
end

TransitionManager._render = function (self, dt)
	local w, h = Gui.resolution()
	local color = self._color:unbox()

	Gui.rect(self._gui, Vector3(0, 0, 0), Vector2(w, h), Color(self._fade * 255, color.x, color.y, color.z))
end

TransitionManager.update = function (self, dt)
	if self._fade_state == "out" then
		return
	elseif self._fade_state == "in" then
		self:_render(dt)

		return
	end

	self._fade = self._fade + self._fade_speed * dt

	if self._fade_state == "fade_in" and self._fade >= 1 then
		self._fade = 1
		self._fade_state = "in"

		if self._callback then
			self._callback()

			self._callback = nil
		end
	elseif self._fade_state == "fade_out" and self._fade <= 0 then
		self._fade = 0
		self._fade_state = "out"

		if self._callback then
			self._callback()

			self._callback = nil
		end

		return
	end

	self:_render(dt)
end
