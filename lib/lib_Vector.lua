
--
-- Vector library - basic math functionality for vectors
--   by: Lutz Justen
--

Vector = {}

require "math";

Vec2 = {}
Vec3 = {};
mathex = {};

function mathex.clamp(x, min, max)
	if (x < min) then x = min; end;
	if (x > max) then x = max; end;
	return x;
end

function Vector.New(n, ...)
	if n == 2 then
		return Vec2.New(...)
	elseif n == 3 then
		return Vec3.New(...)
	else
		error("Invalid Vector size")
	end
end

--------------
-- Vector 2 --
--------------
function Vec2.New(_x, _y)
	return { x = _x or 0,
		     y = _y or 0 };
end

function Vec2.Copy(v)
	return { x = v.x,
		     y = v.y };
end

function Vec2.Add(v1, v2)
	return { x = v1.x + v2.x,
		     y = v1.y + v2.y };
end

function Vec2.Sub(v1, v2)
	return { x = v1.x - v2.x,
		     y = v1.y - v2.y };
end

function Vec2.Lerp(v1, v2, f)
	return { x = v1.x + f * (v2.x - v1.x),
		     y = v1.y + f * (v2.y - v1.y) };
end

function Vec2.Length(v)
	return math.sqrt(v.x * v.x + v.y * v.y);
end

function Vec2.Dot(v1, v2)
	return (v1.x * v2.x + v1.y * v2.y);
end

function Vec2.Distance(v1, v2)
	local v = Vec2.Sub(v1, v2);
	return Vec2.Length(v);
end

function Vec2.Div(v, num)
	return { x = v.x / num,
			y = v.y / num }
end

function Vec2.Normalize(v)
	return Vec2.Div(v, Vec2.Length(v))
end

--------------
-- Vector 3 --
--------------
function Vec3.New(_x, _y, _z)
	return { x = _x or 0,
		     y = _y or 0,
		     z = _z or 0 };
end

function Vec3.Copy(v)
	return { x = v.x,
		     y = v.y,
		     z = v.z };
end

function Vec3.Add(v1, v2)
	return { x = v1.x + v2.x,
		     y = v1.y + v2.y,
		     z = v1.z + v2.z };
end

function Vec3.Sub(v1, v2)
	return { x = v1.x - v2.x,
		     y = v1.y - v2.y,
		     z = v1.z - v2.z };
end

function Vec3.Lerp(v1, v2, f)
	return { x = v1.x + f * (v2.x - v1.x),
		     y = v1.y + f * (v2.y - v1.y),
		     z = v1.z + f * (v2.z - v1.z) };
end

function Vec3.Length(v)
	return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
end

function Vec3.Dot(v1, v2)
	return (v1.x * v2.x + v1.y * v2.y + v1.z * v2.z);
end

function Vec3.Distance(v1, v2)
	local v = Vec3.Sub(v1, v2);
	return Vec3.Length(v);
end


