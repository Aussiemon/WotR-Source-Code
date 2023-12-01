-- chunkname: @scripts/entity_system/systems/behaviour/nodes/bt_pick_random_node_filter.lua

require("scripts/entity_system/systems/behaviour/nodes/bt_node")

BTPickRandomNodeFilter = class(BTPickRandomNodeFilter, BTNode)

BTPickRandomNodeFilter.init = function (self, ...)
	BTPickRandomNodeFilter.super.init(self, ...)

	self._children = {}
end

BTPickRandomNodeFilter.setup = function (self, unit, blackboard, profile)
	self:_setup_weights(unit)

	local sum_of_weights = 0

	for _, weight in ipairs(self._weights) do
		sum_of_weights = sum_of_weights + weight
	end

	self._sum_of_weights = sum_of_weights

	for _, child_node in ipairs(self._children) do
		child_node:setup(unit, blackboard, profile)
	end

	self._active_child = self:_random_new_child()
end

BTPickRandomNodeFilter.run = function (self, unit, blackboard, t, dt)
	local result = self._active_child:run(unit, blackboard, t, dt)

	if not result then
		self._active_child = self:_random_new_child()
	end
end

BTPickRandomNodeFilter.add_child = function (self, node)
	self._children[#self._children + 1] = node
end

BTPickRandomNodeFilter._random_new_child = function (self)
	local rand = math.random(1, self._sum_of_weights)

	for index, weight in ipairs(self._weights) do
		if rand <= weight then
			return self._children[index]
		end

		rand = rand - weight
	end
end

BTPickRandomNodeFilter._setup_weights = function (self, unit)
	local num_weights = #self._data.weights
	local num_children = #self._children

	fassert(num_weights == num_children, "Number of weights should be = number of child nodes (num weights = %d, num children %d) for node %q", num_weights, num_children, self._name)

	self._weights = self._data.weights
end
