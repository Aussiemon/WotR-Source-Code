-- chunkname: @scripts/managers/backend/backend_manager.lua

require("scripts/managers/backend/script_backend_token")

BackendManager = class(BackendManager)

BackendManager.available = function (self)
	return script_data.settings.backend and rawget(_G, "Backend") ~= nil
end

BackendManager.connect = function (self, ip_address, project_id, connection_type, port, interface, callback)
	local token = Backend.connect(ip_address, project_id, connection_type, port, interface)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.connected = function (self)
	return Backend.connected()
end

BackendManager.login = function (self, username, password, callback)
	local token = Backend.login(username, password)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.steam_login = function (self, callback)
	local token = Backend.steam_login()
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.create_profile = function (self, profile_name, profile_data, profile_attributes, callback)
	local token = Backend.create_profile(profile_name, profile_data, profile_attributes)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.select_profile = function (self, profile_id, callback)
	local token = Backend.select_profile(profile_id)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.update_profile = function (self, profile_data, callback)
	local token = Backend.update_profile(profile_data)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.drop_profile = function (self, profile_id, callback)
	local token = Backend.drop_profile(profile_id)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.set_profile_attribute = function (self, profile_id, attribute_name, attribute_value, callback)
	local token = Backend.set_profile_attribute(profile_id, attribute_name, attribute_value)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.set_profile_attributes = function (self, profile_id, attributes, callback)
	local token = Backend.set_profile_attributes(profile_id, attributes)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.update_profile_attributes = function (self, profile_id, attributes, callback)
	local token = Backend.update_profile_attributes(profile_id, attributes, callback)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.get_profile_attributes = function (self, profile_id, callback)
	local token = Backend.get_profile_attributes(profile_id)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.create_entity = function (self, profile_id, entity_type_id, entity_name, entity_attributes, callback)
	local token = Backend.create_entity(profile_id, entity_type_id, entity_name, entity_attributes)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.create_entities = function (self, entities, callback)
	local token = Backend.create_entities(entities)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.drop_entity = function (self, entity_id, callback)
	local token = Backend.drop_entity(entity_id)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.get_entities = function (self, profile_id, callback)
	local token = Backend.get_entities(profile_id)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.get_entity_types = function (self, callback)
	local token = Backend.get_entity_types()
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.set_entity_attribute = function (self, entity_id, attribute_name, attribute_value, callback)
	local token = Backend.set_entity_attribute(entity_id, attribute_name, attribute_value)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.save_stats = function (self, stats, callback)
	local token = Backend.save_stats(stats)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.load_stats = function (self, group_name, owners, callback)
	local token = Backend.load_stats(group_name, type(owners) == "table" and unpack(owners) or owners)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.save_telemetry = function (self, group_name, data, callback)
	local token = Backend.save_telemetry(group_name, data)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.get_currencies = function (self, callback)
	local token = Backend.get_currencies()
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.get_market_items = function (self, all_items, callback)
	local token = Backend.get_market_items(all_items or false)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.purchase_item = function (self, market_item_id, currency_id, callback)
	local token = Backend.purchase_item(market_item_id, currency_id)
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.get_store_items = function (self, callback)
	local token = Backend.get_store_items()
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.purchase_store_item = function (self, item_id, quantity, callback)
	local token = Backend.purchase_store_item(item_id, quantity, Steam:language())
	local backend_token = ScriptBackendToken:new(token)

	Managers.token:register_token(backend_token, callback)
end

BackendManager.logout = function (self, callback)
	Backend.logout()
end

BackendManager.disconnect = function (self, callback)
	Backend.disconnect()
end
