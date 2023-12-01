-- chunkname: @scripts/managers/persistence/persistence_manager_client_offline.lua

PersistenceManagerClientOffline = class(PersistenceManagerClientOffline)

PersistenceManagerClientOffline.init = function (self)
	print("PersistenceManagerClientOffline")
end

PersistenceManagerClientOffline.connect = function (self, connect_callback)
	connect_callback()
end

PersistenceManagerClientOffline.load_market = function (self, market_callback)
	market_callback({})
end

PersistenceManagerClientOffline.load_store = function (self, store_callback)
	store_callback({})
end

PersistenceManagerClientOffline.profile_id = function (self)
	return -1
end

PersistenceManagerClientOffline.load_profile = function (self, profile_callback)
	profile_callback({})
end

PersistenceManagerClientOffline.profile_data = function (self)
	return nil
end

PersistenceManagerClientOffline.store = function (self)
	return {}
end

PersistenceManagerClientOffline.update = function (self)
	return
end
