-- chunkname: @foundation/scripts/util/error.lua

local function format_error_message(message, ...)
	local args = {}

	for i = 1, select("#", ...) do
		args[i] = tostring(select(i, ...))
	end

	return string.format(message, unpack(args))
end

Application.warning = function (...)
	if Application.build() ~= "release" then
		Application.console_send({
			system = "Lua",
			level = "warning",
			type = "message",
			message = format_error_message(...)
		})
	end
end

Application.error = function (...)
	if Application.build() ~= "release" then
		Application.console_send({
			system = "Lua",
			level = "error",
			type = "message",
			message = format_error_message(...)
		})
	end
end

function fassert(condition, message, ...)
	if not condition then
		local message = format_error_message(message, ...)

		assert(false, message)
	end
end

function ferror(message, ...)
	local message = format_error_message(message, ...)

	error(message)
end
