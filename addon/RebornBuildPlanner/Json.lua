-- Strict JSON parser and JSON.stringify-compatible encoder for Lua 5.1. Original code (no third-party library,
-- so no licence to carry). It parses TEXT into plain data only: nothing is ever executed or compiled.
--
-- Decode(text, limits) -> value | nil, err{code,message,pos}
--   limits: maxBytes (default 98304), maxDepth (8), maxNodes (5000)
--   null -> Json.null (sentinel table); arrays carry Json.ArrayMT, objects Json.ObjectMT.
--   Rejected: trailing text, comments, NaN/Infinity, leading zeros, raw control characters in strings,
--   bad escapes, numbers that overflow to infinity, anything beyond the limits.
--   A lone UTF-16 surrogate escape (\ud800) becomes U+FFFD (what JavaScript yields after re-encoding).
-- Encode(value) -> text, JSON.stringify layout (no spaces, non-ASCII left as is, control characters escaped).
local ADDON, ns = ...;
ns = ns or {};
local Json = {};
ns.Json = Json;

local byte, char, sub, find, format, concat = string.byte, string.char, string.sub, string.find, string.format, table.concat;
local floor = math.floor;
local Utf8 = ns.Utf8;
assert(Utf8, "RebornBuildPlanner: Utf8.lua has to come first in the .toc");

Json.null = setmetatable({}, { __tostring = function() return "null"; end });
Json.ArrayMT = { __name = "json-array" };
Json.ObjectMT = { __name = "json-object" };
Json.DEFAULTS = { maxBytes = 98304, maxDepth = 8, maxNodes = 5000 };

function Json.Array(t)
	return setmetatable(t or {}, Json.ArrayMT);
end

function Json.IsArray(v)
	return type(v) == "table" and getmetatable(v) == Json.ArrayMT;
end

function Json.IsObject(v)
	return type(v) == "table" and getmetatable(v) == Json.ObjectMT;
end

local function fail(code, message, pos)
	error({ json = true, code = code, message = message, pos = pos }, 0);
end

-- ------------------------------------------------------------------ decoder
local ESC = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" };

local function skip(s, i)
	local _, e = find(s, "^[ \t\n\r]*", i);
	return e + 1;
end

local function hex4(s, i)
	local h = sub(s, i, i + 3);
	if not find(h, "^%x%x%x%x$") then
		fail("BAD_ESCAPE", "invalid \\u escape", i);
	end
	return tonumber(h, 16);
end

local function parseString(s, i)
	-- s[i] is the opening quote
	local out, n = {}, 0;
	local pos = i + 1;
	while true do
		local a = find(s, '[%z\1-\31"\\]', pos);
		if not a then
			fail("UNTERMINATED", "unterminated string", i);
		end
		if a > pos then
			n = n + 1;
			out[n] = sub(s, pos, a - 1);
		end
		local c = byte(s, a);
		if c == 34 then
			return concat(out), a + 1;
		elseif c == 92 then
			local e = sub(s, a + 1, a + 1);
			if ESC[e] then
				n = n + 1;
				out[n] = ESC[e];
				pos = a + 2;
			elseif e == "u" then
				local cp = hex4(s, a + 2);
				pos = a + 6;
				if cp >= 0xD800 and cp <= 0xDBFF then
					if sub(s, pos, pos + 1) == "\\u" then
						local lo = hex4(s, pos + 2);
						if lo >= 0xDC00 and lo <= 0xDFFF then
							cp = 0x10000 + (cp - 0xD800) * 1024 + (lo - 0xDC00);
							pos = pos + 6;
						else
							cp = 0xFFFD;
						end
					else
						cp = 0xFFFD;
					end
				elseif cp >= 0xDC00 and cp <= 0xDFFF then
					cp = 0xFFFD;
				end
				n = n + 1;
				out[n] = Utf8.Encode(cp);
			else
				fail("BAD_ESCAPE", "invalid escape", a);
			end
		else
			fail("CONTROL_CHARACTER", "raw control character in string", a);
		end
	end
end

local function parseNumber(s, i)
	local _, e = find(s, "^-?", i);
	local p = e + 1;
	local _, z = find(s, "^0", p);
	if z then
		p = z + 1;
	else
		local _, d = find(s, "^[1-9]%d*", p);
		if not d then
			fail("BAD_NUMBER", "invalid number", i);
		end
		p = d + 1;
	end
	local _, f = find(s, "^%.%d+", p);
	if f then p = f + 1; elseif sub(s, p, p) == "." then fail("BAD_NUMBER", "invalid number", i); end
	local _, x = find(s, "^[eE][+-]?%d+", p);
	if x then p = x + 1; elseif find(s, "^[eE]", p) then fail("BAD_NUMBER", "invalid number", i); end
	local v = tonumber(sub(s, i, p - 1));
	if not v or v ~= v or v == 1 / 0 or v == -1 / 0 then
		fail("BAD_NUMBER", "number out of range", i);
	end
	return v, p;
end

function Json.Decode(text, limits)
	if type(text) ~= "string" then
		return nil, { code = "NOT_TEXT", message = "text expected" };
	end
	limits = limits or {};
	local maxBytes = limits.maxBytes or Json.DEFAULTS.maxBytes;
	local maxDepth = limits.maxDepth or Json.DEFAULTS.maxDepth;
	local maxNodes = limits.maxNodes or Json.DEFAULTS.maxNodes;
	if #text > maxBytes then
		return nil, { code = "TOO_LARGE", message = "JSON text of " .. #text .. " bytes exceeds " .. maxBytes };
	end
	local s = text;
	local nodes = 0;
	local function value(i, depth)
		nodes = nodes + 1;
		if nodes > maxNodes then
			fail("TOO_MANY_NODES", "more than " .. maxNodes .. " values", i);
		end
		local c = sub(s, i, i);
		if c == "[" or c == "{" then
			if depth >= maxDepth then
				fail("TOO_DEEP", "nesting deeper than " .. maxDepth, i);
			end
			local closer = (c == "[") and "]" or "}";
			local isArray = c == "[";
			local t = setmetatable({}, isArray and Json.ArrayMT or Json.ObjectMT);
			local j = skip(s, i + 1);
			if sub(s, j, j) == closer then
				return t, j + 1;
			end
			local count = 0;
			while true do
				if isArray then
					local v
					v, j = value(j, depth + 1);
					count = count + 1;
					t[count] = v;
				else
					if sub(s, j, j) ~= '"' then
						fail("BAD_OBJECT", "object key expected", j);
					end
					local k
					k, j = parseString(s, j);
					j = skip(s, j);
					if sub(s, j, j) ~= ":" then
						fail("BAD_OBJECT", "':' expected", j);
					end
					local v
					v, j = value(skip(s, j + 1), depth + 1);
					t[k] = v;
				end
				j = skip(s, j);
				local d = sub(s, j, j);
				if d == "," then
					j = skip(s, j + 1);
				elseif d == closer then
					return t, j + 1;
				else
					fail("BAD_SYNTAX", "',' or '" .. closer .. "' expected", j);
				end
			end
		elseif c == '"' then
			return parseString(s, i);
		elseif c == "-" or find(c, "^%d") then
			return parseNumber(s, i);
		elseif sub(s, i, i + 3) == "true" then
			return true, i + 4;
		elseif sub(s, i, i + 4) == "false" then
			return false, i + 5;
		elseif sub(s, i, i + 3) == "null" then
			return Json.null, i + 4;
		end
		fail("BAD_SYNTAX", "unexpected character", i);
	end
	local ok, v = pcall(function()
		local i = skip(s, 1);
		local val, j = value(i, 0);
		j = skip(s, j);
		if j <= #s then
			fail("TRAILING", "unexpected text after the value", j);
		end
		return val, j;
	end);
	if not ok then
		if type(v) == "table" and v.json then
			return nil, { code = v.code, message = v.message, pos = v.pos };
		end
		return nil, { code = "INTERNAL", message = tostring(v) };
	end
	return v;
end

-- ------------------------------------------------------------------ encoder
local function quote(str)
	if not Utf8.Validate(str) then
		error({ json = true, code = "INVALID_UTF8", message = "string is not valid UTF-8" }, 0);
	end
	local r = string.gsub(str, '[%z\1-\31"\\]', function(c)
		local b = byte(c);
		if c == '"' then return '\\"'; end
		if c == "\\" then return "\\\\"; end
		if b == 8 then return "\\b"; end
		if b == 9 then return "\\t"; end
		if b == 10 then return "\\n"; end
		if b == 12 then return "\\f"; end
		if b == 13 then return "\\r"; end
		return format("\\u%04x", b);
	end);
	return '"' .. r .. '"';
end
Json.Quote = quote;

-- ECMAScript Number::toString for finite doubles (shortest round-trip digits, JS exponent rules).
function Json.FormatNumber(x)
	if x ~= x or x == 1 / 0 or x == -1 / 0 then
		error({ json = true, code = "BAD_NUMBER", message = "non-finite number" }, 0);
	end
	if x == 0 then
		return "0";
	end
	local sign = "";
	if x < 0 then
		sign, x = "-", -x;
	end
	local digits, exp;
	for p = 0, 16 do
		local str = format("%." .. p .. "e", x);
		if tonumber(str) == x then
			local m, e = string.match(str, "^([%d%.]+)e([+-]%d+)$");
			digits = string.gsub(m, "%.", "");
			exp = tonumber(e);
			break;
		end
	end
	digits = string.gsub(digits, "0+$", "");
	if digits == "" then digits = "0"; end
	local k, n = #digits, exp + 1;
	local out;
	if k <= n and n <= 21 then
		out = digits .. string.rep("0", n - k);
	elseif 0 < n and n <= 21 then
		out = sub(digits, 1, n) .. "." .. sub(digits, n + 1);
	elseif -6 < n and n <= 0 then
		out = "0." .. string.rep("0", -n) .. digits;
	else
		local e = n - 1;
		local es = (e < 0 and "-" or "+") .. math.abs(e);
		out = (k == 1) and (digits .. "e" .. es) or (sub(digits, 1, 1) .. "." .. sub(digits, 2) .. "e" .. es);
	end
	return sign .. out;
end

local function enc(v, out, depth)
	if depth > 16 then
		error({ json = true, code = "TOO_DEEP", message = "value nested too deeply" }, 0);
	end
	local t = type(v);
	if v == Json.null then
		out[#out + 1] = "null";
	elseif t == "string" then
		out[#out + 1] = quote(v);
	elseif t == "number" then
		out[#out + 1] = Json.FormatNumber(v);
	elseif t == "boolean" then
		out[#out + 1] = v and "true" or "false";
	elseif t == "table" then
		out[#out + 1] = "[";
		for i = 1, #v do
			if i > 1 then out[#out + 1] = ","; end
			enc(v[i], out, depth + 1);
		end
		out[#out + 1] = "]";
	else
		error({ json = true, code = "UNSUPPORTED", message = "cannot encode a " .. t }, 0);
	end
end

-- Arrays only (tables are written as JSON arrays; Json.null is null). Returns text | nil, err.
function Json.Encode(v)
	local out = {};
	local ok, e = pcall(enc, v, out, 0);
	if not ok then
		if type(e) == "table" and e.json then
			return nil, { code = e.code, message = e.message };
		end
		return nil, { code = "INTERNAL", message = tostring(e) };
	end
	return concat(out);
end
