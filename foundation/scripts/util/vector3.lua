-- chunkname: @foundation/scripts/util/vector3.lua

Vector3.flat = function (v)
	return Vector3(v[1], v[2], 0)
end

Vector3.step = function (start, target, step_size)
	local offset = target - start
	local distance = Vector3.length(offset)

	if distance < step_size then
		return target, true
	else
		return start + Vector3.normalize(offset) * step_size, false
	end
end

Vector3.smoothstep = function (t, v1, v2)
	local smoothstep = math.smoothstep(t, 0, 1)

	return Vector3.lerp(v1, v2, smoothstep)
end

Vector3.clamp = function (v, min, max)
	return Vector3(math.clamp(v.x, min, max), math.clamp(v.y, min, max), math.clamp(v.z, min, max))
end
