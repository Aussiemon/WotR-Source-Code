-- chunkname: @scripts/managers/persistence/persistence_manager_server_offline.lua

PersistenceManagerServerOffline = class(PersistenceManagerServerOffline)

PersistenceManagerServerOffline.init = function (self)
	print("PersistenceManagerServerOffline:init")
end

PersistenceManagerServerOffline.post_init = function (self)
	return
end

PersistenceManagerServerOffline.setup = function (self)
	return
end

PersistenceManagerServerOffline.save = function (self, callback)
	callback()
end

PersistenceManagerServerOffline.process_unlocks = function (self)
	return
end

PersistenceManagerServerOffline.update = function (self, t, dt)
	return
end
