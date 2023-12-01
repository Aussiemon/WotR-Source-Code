-- chunkname: @foundation/scripts/managers/world/world_manager.lua

require("foundation/scripts/util/script_world")

WorldManager = class(WorldManager)

WorldManager.init = function (self)
	self._worlds = {}
	self._update_queue = {}
end

WorldManager.create_world = function (self, name, shading_environment, shading_callback, layer, ...)
	fassert(self._worlds[name] == nil, "World %q already exists", name)

	local world = Application.new_world(...)

	World.set_data(world, "name", name)
	World.set_data(world, "layer", layer or 1)
	World.set_data(world, "active", true)

	if shading_environment then
		ScriptWorld.create_shading_environment(world, shading_environment, shading_callback, "default")
	end

	World.set_data(world, "levels", {})
	World.set_data(world, "viewports", {})
	World.set_data(world, "free_flight_viewports", {})
	World.set_data(world, "render_queue", {})

	self._worlds[name] = world

	self:_sort_update_queue()

	return world
end

WorldManager.destroy_world = function (self, world_or_name)
	local name

	if type(world_or_name) == "string" then
		name = world_or_name
	else
		name = World.get_data(world_or_name, "name")
	end

	fassert(self._worlds[name], "World %q doesn't exist", name)
	Application.release_world(self._worlds[name])

	self._worlds[name] = nil

	self:_sort_update_queue()
end

WorldManager.has_world = function (self, name)
	return self._worlds[name] ~= nil
end

WorldManager.world = function (self, name)
	fassert(self._worlds[name], "World %q doesn't exist", name)

	return self._worlds[name]
end

WorldManager.update = function (self, dt)
	for _, world in ipairs(self._update_queue) do
		ScriptWorld.update(world, dt)
	end
end

WorldManager.render = function (self)
	for _, world in ipairs(self._update_queue) do
		ScriptWorld.render(world)
	end
end

WorldManager.destroy = function (self)
	for name, _ in pairs(self._worlds) do
		self:destroy_world(name)
	end
end

WorldManager._sort_update_queue = function (self)
	self._update_queue = {}

	for name, world in pairs(self._worlds) do
		self._update_queue[#self._update_queue + 1] = world
	end

	local function comparator(w1, w2)
		return World.get_data(w1, "layer") < World.get_data(w2, "layer")
	end

	table.sort(self._update_queue, comparator)
end
