-- base64url (RFC 4648 §5) without padding for encoding; a decoder that accepts what the official planner's
-- atob-based decoder accepts (both alphabets, optional padding, ASCII whitespace). Original code.
local ADDON, ns = ...;
ns = ns or {};
local B = {};
ns.Base64Url = B;

local byte, char, sub, concat = string.byte, string.char, string.sub, table.concat;
local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
local ENC, DEC = {}, {};
for i = 1, 64 do
	local c = sub(ALPHA, i, i);
	ENC[i - 1] = c;
	DEC[byte(c)] = i - 1;
end
DEC[byte("+")] = 62;
DEC[byte("/")] = 63;

function B.Encode(s)
	local out, n = {}, #s;
	for i = 1, n, 3 do
		local a, b, c = byte(s, i, i + 2);
		local v = a * 65536 + (b or 0) * 256 + (c or 0);
		local c1, c2, c3, c4 = math.floor(v / 262144) % 64, math.floor(v / 4096) % 64, math.floor(v / 64) % 64, v % 64;
		if c then
			out[#out + 1] = ENC[c1] .. ENC[c2] .. ENC[c3] .. ENC[c4];
		elseif b then
			out[#out + 1] = ENC[c1] .. ENC[c2] .. ENC[c3];
		else
			out[#out + 1] = ENC[c1] .. ENC[c2];
		end
	end
	return concat(out);
end

-- Returns bytes or nil, reason. maxChars bounds the INPUT before any work.
function B.Decode(text, maxChars)
	if type(text) ~= "string" then
		return nil, "not a string";
	end
	if maxChars and #text > maxChars then
		return nil, "too long";
	end
	local s = string.gsub(text, "[ \t\n\f\r]", "");
	if #s % 4 == 0 then
		if sub(s, -2) == "==" then
			s = sub(s, 1, -3);
		elseif sub(s, -1) == "=" then
			s = sub(s, 1, -2);
		end
	end
	if #s % 4 == 1 then
		return nil, "invalid length";
	end
	local out, n = {}, #s;
	for i = 1, n, 4 do
		local a, b, c, d = byte(s, i, i + 3);
		local va, vb, vc, vd = DEC[a], DEC[b], c and DEC[c], d and DEC[d];
		if not va or not vb or (c and not vc) or (d and not vd) then
			return nil, "invalid character";
		end
		local v = va * 262144 + vb * 4096 + (vc or 0) * 64 + (vd or 0);
		if d then
			out[#out + 1] = char(math.floor(v / 65536), math.floor(v / 256) % 256, v % 256);
		elseif c then
			out[#out + 1] = char(math.floor(v / 65536), math.floor(v / 256) % 256);
		else
			out[#out + 1] = char(math.floor(v / 65536));
		end
	end
	return concat(out);
end
