-- UTF-8 helpers (Lua 5.1 strings are bytes). Validation is strict (no overlongs, no surrogates, <= U+10FFFF).
-- Length/slicing are expressed in UTF-16 code units, because the official planner (JavaScript) counts and
-- slices that way. Original code.
local ADDON, ns = ...;
ns = ns or {};
local Utf8 = {};
ns.Utf8 = Utf8;

local byte, char, sub, floor = string.byte, string.char, string.sub, math.floor;

Utf8.REPLACEMENT = "\239\191\189";   -- U+FFFD

-- Decodes the code point starting at byte i. Returns cp, nextIndex or nil, reason.
local function decode(s, i)
	local c = byte(s, i);
	if c < 0x80 then
		return c, i + 1;
	elseif c < 0xC2 then
		return nil, "bad lead byte";
	elseif c < 0xE0 then
		local c2 = byte(s, i + 1);
		if not c2 or c2 < 0x80 or c2 > 0xBF then return nil, "truncated"; end
		return (c - 0xC0) * 64 + (c2 - 0x80), i + 2;
	elseif c < 0xF0 then
		local c2, c3 = byte(s, i + 1, i + 2);
		if not c3 or c2 < 0x80 or c2 > 0xBF or c3 < 0x80 or c3 > 0xBF then return nil, "truncated"; end
		local cp = (c - 0xE0) * 4096 + (c2 - 0x80) * 64 + (c3 - 0x80);
		if cp < 0x800 then return nil, "overlong"; end
		if cp >= 0xD800 and cp <= 0xDFFF then return nil, "surrogate"; end
		return cp, i + 3;
	elseif c < 0xF5 then
		local c2, c3, c4 = byte(s, i + 1, i + 3);
		if not c4 or c2 < 0x80 or c2 > 0xBF or c3 < 0x80 or c3 > 0xBF or c4 < 0x80 or c4 > 0xBF then return nil, "truncated"; end
		local cp = (c - 0xF0) * 262144 + (c2 - 0x80) * 4096 + (c3 - 0x80) * 64 + (c4 - 0x80);
		if cp < 0x10000 then return nil, "overlong"; end
		if cp > 0x10FFFF then return nil, "out of range"; end
		return cp, i + 4;
	end
	return nil, "bad lead byte";
end
Utf8.Decode = decode;

-- Basic Unicode case folding for catalogue search. Lua 5.1 string.lower
-- only converts ASCII, so a Cyrillic query typed in lowercase would not
-- match the official Russian capitalized name. This deliberately handles
-- common European game locales without changing saved identifiers.
local LOWER_EXCEPT = {
  [0x0130] = 0x0069, [0x0401] = 0x0451, [0x0404] = 0x0454,
  [0x0406] = 0x0456, [0x0407] = 0x0457, [0x0490] = 0x0491,
  [0x0141] = 0x0142, [0x0178] = 0x00FF,
}
for _, pair in ipairs({
  {0x0104,0x0105}, {0x0106,0x0107}, {0x010C,0x010D},
  {0x0118,0x0119}, {0x011A,0x011B}, {0x0143,0x0144},
  {0x0147,0x0148}, {0x015A,0x015B}, {0x015E,0x015F},
  {0x0160,0x0161}, {0x0164,0x0165}, {0x0179,0x017A},
  {0x017B,0x017C}, {0x017D,0x017E}, {0x011E,0x011F}
}) do LOWER_EXCEPT[pair[1]] = pair[2] end

function Utf8.CaseFold(text)
  if type(text) ~= "string" then return "" end
  local out, i = {}, 1
  while i <= #text do
    local cp, nextIndex = decode(text, i)
    if not cp then return string.lower(text) end
    if cp >= 0x41 and cp <= 0x5A then cp = cp + 32
    elseif (cp >= 0x00C0 and cp <= 0x00D6) or (cp >= 0x00D8 and cp <= 0x00DE) then cp = cp + 32
    elseif cp >= 0x0410 and cp <= 0x042F then cp = cp + 32
    elseif cp >= 0x0391 and cp <= 0x03AB and cp ~= 0x03A2 then cp = cp + 32
    else cp = LOWER_EXCEPT[cp] or cp end
    out[#out+1] = Utf8.Encode(cp)
    i = nextIndex
  end
  return table.concat(out)
end



function Utf8.Encode(cp)
	if cp < 0x80 then
		return char(cp);
	elseif cp < 0x800 then
		return char(0xC0 + floor(cp / 64), 0x80 + cp % 64);
	elseif cp < 0x10000 then
		return char(0xE0 + floor(cp / 4096), 0x80 + floor(cp / 64) % 64, 0x80 + cp % 64);
	end
	return char(0xF0 + floor(cp / 262144), 0x80 + floor(cp / 4096) % 64, 0x80 + floor(cp / 64) % 64, 0x80 + cp % 64);
end

-- true, or false + byte position + reason
function Utf8.Validate(s)
	local i, n = 1, #s;
	while i <= n do
		local c = byte(s, i);
		if c < 0x80 then
			i = i + 1;
		else
			local cp, nxt = decode(s, i);
			if not cp then
				return false, i, nxt;
			end
			i = nxt;
		end
	end
	return true;
end

-- Length in UTF-16 code units of a VALID UTF-8 string.
function Utf8.Len16(s)
	local n, i, len = 0, 1, #s;
	while i <= len do
		local c = byte(s, i);
		if c < 0x80 then
			n, i = n + 1, i + 1;
		elseif c < 0xE0 then
			n, i = n + 1, i + 2;
		elseif c < 0xF0 then
			n, i = n + 1, i + 3;
		else
			n, i = n + 2, i + 4;
		end
	end
	return n;
end

-- First `limit` UTF-16 units of a valid string, like JavaScript's slice(0, limit). A cut through a surrogate
-- pair keeps nothing of that character but a U+FFFD (what JavaScript yields once the string is re-encoded).
-- Returns text, truncated (boolean), originalLength16.
function Utf8.Slice16(s, limit)
	local units, i, len = 0, 1, #s;
	local total = Utf8.Len16(s);
	if total <= limit then
		return s, false, total;
	end
	while i <= len do
		local c = byte(s, i);
		local width, u;
		if c < 0x80 then width, u = 1, 1; elseif c < 0xE0 then width, u = 2, 1; elseif c < 0xF0 then width, u = 3, 1; else width, u = 4, 2; end
		if units + u > limit then
			local head = sub(s, 1, i - 1);
			if units < limit then
				head = head .. Utf8.REPLACEMENT;          -- only possible inside a pair
			end
			return head, true, total;
		end
		units, i = units + u, i + width;
	end
	return s, false, total;
end

-- JavaScript String.prototype.trim whitespace (WhiteSpace + LineTerminator).
local SPACE = { [0x09] = true, [0x0A] = true, [0x0B] = true, [0x0C] = true, [0x0D] = true, [0x20] = true, [0xA0] = true,
	[0x1680] = true, [0x2028] = true, [0x2029] = true, [0x202F] = true, [0x205F] = true, [0x3000] = true, [0xFEFF] = true };
function Utf8.IsSpace(cp)
	return SPACE[cp] == true or (cp >= 0x2000 and cp <= 0x200A);
end

function Utf8.Trim(s)
	local i, n = 1, #s;
	while i <= n do
		local cp, nxt = decode(s, i);
		if not cp or not Utf8.IsSpace(cp) then break; end
		i = nxt;
	end
	local j = n;
	while j >= i do
		local k = j;
		while k > i and byte(s, k) >= 0x80 and byte(s, k) < 0xC0 do k = k - 1; end   -- back to the lead byte
		local cp = decode(s, k);
		if not cp or not Utf8.IsSpace(cp) then break; end
		j = k - 1;
	end
	return sub(s, i, j);
end

-- true when the string holds a JavaScript `\s` character (same set as trim).
function Utf8.HasSpace(s)
	local i, n = 1, #s;
	while i <= n do
		local cp, nxt = decode(s, i);
		if not cp then return false; end
		if Utf8.IsSpace(cp) then return true; end
		i = nxt;
	end
	return false;
end
