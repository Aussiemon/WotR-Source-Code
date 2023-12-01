-- chunkname: @foundation/scripts/managers/chat/chat_logger.lua

ChatLogger = class(ChatLogger)

ChatLogger.init = function (self, file_name)
	self._filepath = file_name
	self._stringformat_callback = {}
end

ChatLogger.subscribe = function (self)
	self._file = TextFile(self._filepath, "w")

	Managers.state.event:register(self, "event_chat_message", "event_chat_message")
	Managers.state.event:register(self, "event_admin_chat_message", "event_admin_chat_message")
	Managers.state.event:register(self, "event_rcon_chat_message", "event_rcon_chat_message")
end

ChatLogger.set_stringformat_callback = function (self, name, func)
	self._stringformat_callback[name] = func
end

ChatLogger.event_chat_message = function (self, channel_id, sender, message)
	if self._stringformat_callback.chat then
		self._file:write(self._stringformat_callback.chat(channel_id, sender, message))
	else
		self._file:write(self:_default_string_forchat(channel_id, sender, message))
	end
end

ChatLogger.event_admin_chat_message = function (self, channel_id, sender, message)
	if self._stringformat_callback.admin then
		self._file:write(self._stringformat_callback.admin(channel_id, sender, message))
	else
		self._file:write(self:_default_string_foradmin(channel_id, sender, message))
	end
end

ChatLogger.event_rcon_chat_message = function (self, channel_id, sender, message)
	if self._stringformat_callback.rcon then
		self._file:write(self._stringformat_callback.rcon(channel_id, sender, message))
	else
		self._file:write(self:_default_string_forrcon(channel_id, sender, message))
	end
end

ChatLogger.write_to_log = function (self, string)
	self._file:write(string)
end

ChatLogger._default_string_forchat = function (self, channel_id, sender, message)
	local channel = NetworkLookup.chat_channels[channel_id]
	local channel_name = L("chat_" .. channel)
	local name = rawget(_G, "Steam") and Steam.user_name(sender) or ""

	return os.date("%a %c ") .. "[" .. channel_name .. "] " .. name .. ": " .. message .. "\n"
end

ChatLogger._default_string_foradmin = function (self, channel_id, sender, message)
	return os.date("%a %c ") .. "[ Admin ]" .. message
end

ChatLogger._default_string_forrcon = function (self, channel_id, sender, message)
	return os.date("%a %c ") .. message
end
