-- Small pure helpers shared by the model and the storage. Lua 5.1 only; no globals written.
local ADDON, ns = ...;
ns = ns or {};
local Util = {};
ns.Util = Util;

local type, pairs, ipairs, next, tostring, setmetatable, getmetatable = type, pairs, ipairs, next, tostring, setmetatable, getmetatable;

-- Deep copy of plain data. Functions/userdata/cycles are errors: the model never holds them.
function Util.DeepCopy(v, seen)
	if type(v) ~= "table" then
		if type(v) == "function" or type(v) == "userdata" or type(v) == "thread" then
			error("DeepCopy: cannot copy a " .. type(v));
		end
		return v;
	end
	seen = seen or {};
	if seen[v] then
		error("DeepCopy: cycle");
	end
	seen[v] = true;
	local out = {};
	for k, x in pairs(v) do
		out[Util.DeepCopy(k, seen)] = Util.DeepCopy(x, seen);
	end
	seen[v] = nil;
	return out;
end

function Util.DeepEqual(a, b)
	if a == b then
		return true;
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false;
	end
	for k, x in pairs(a) do
		if not Util.DeepEqual(x, b[k]) then
			return false;
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false;
		end
	end
	return true;
end

-- Counts nodes and depth; ok=false on a cycle, a function/userdata value, or when the limits are exceeded.
function Util.Measure(v, maxNodes, maxDepth)
	local nodes, deepest, bad = 0, 0, nil;
	local path = {};
	local function walk(x, depth)
		if bad then
			return;
		end
		nodes = nodes + 1;
		if depth > deepest then
			deepest = depth;
		end
		if nodes > maxNodes then
			bad = "too many nodes";
		elseif depth > maxDepth then
			bad = "too deep";
		end
		if bad then
			return;
		end
		local t = type(x);
		if t == "function" or t == "userdata" or t == "thread" then
			bad = "non-data value (" .. t .. ")";
		elseif t == "number" and (x ~= x or x == 1 / 0 or x == -1 / 0) then
			bad = "non-finite number";
		elseif t == "table" then
			if path[x] then
				bad = "cycle";
				return;
			end
			path[x] = true;
			for k, y in pairs(x) do
				walk(k, depth + 1);
				walk(y, depth + 1);
			end
			path[x] = nil;
		end
	end
	walk(v, 0);
	return not bad, bad, nodes, deepest;
end

function Util.IsArray(t)
	if type(t) ~= "table" then
		return false;
	end
	local n = 0;
	for _ in pairs(t) do
		n = n + 1;
	end
	for i = 1, n do
		if t[i] == nil then
			return false;
		end
	end
	return true;
end

function Util.Len(t)
	local n = 0;
	for _ in pairs(t) do
		n = n + 1;
	end
	return n;
end

function Util.IndexOf(list, value)
	for i = 1, #list do
		if list[i] == value then
			return i;
		end
	end
	return nil;
end

-- Sorted keys for deterministic iteration.
function Util.SortedKeys(t)
	local keys = {};
	for k in pairs(t) do
		keys[#keys + 1] = k;
	end
	table.sort(keys, function(a, b)
		local ta, tb = type(a), type(b);
		if ta ~= tb then
			return ta < tb;
		end
		return a < b;
	end);
	return keys;
end
