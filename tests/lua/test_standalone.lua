-- Standalone codec/serialisation tests: need NO catalogue and NO official bundle.
-- Vectors: tests/fixtures/codec/golden.json (outputs of the official site code, generated once by tools/gen_codec_golden.mjs).
return function(H)
	local eq, ok, test = H.eq, H.ok, H.test;
	local ns = H.loadAddon({ only = { "Util.lua", "Locale.lua", "Utf8.lua", "Base64Url.lua", "Json.lua" } });
	local J, B64, Utf8 = ns.Json, ns.Base64Url, ns.Utf8;
	local PREFIX = "azsb1:";

	local golden = assert(J.Decode(H.readFile(H.root .. "/tests/fixtures/codec/golden.json"), { maxBytes = 8000000, maxDepth = 12, maxNodes = 3000000 }));
	local codes = {};
	local function walk(v)
		if type(v) == "string" then
			if v:sub(1, #PREFIX) == PREFIX then codes[#codes + 1] = v; end
		elseif type(v) == "table" then
			for _, x in pairs(v) do walk(x); end
		end
	end
	walk(golden);

	test("golden vectors present", function() ok(#codes >= 8, "at least 8 official codes in golden.json (" .. #codes .. ")"); end);

	test("official codes: base64url -> JSON -> JSON -> base64url is the identity (valid plan arrays)", function()
		local n = 0;
		for i, code in ipairs(codes) do
			local raw = B64.Decode(code:sub(#PREFIX + 1));
			local v = raw and J.Decode(raw);
			if v and J.IsArray(v) then
				n = n + 1;
				local again = J.Encode(v);
				eq(again, raw, "code " .. i .. " JSON round trip is byte-identical");
				eq(PREFIX .. B64.Encode(again), code, "code " .. i .. " re-encodes to the same string");
			end
		end
		ok(n >= 8, "at least 8 valid official plan codes exercised (" .. n .. ")");
	end);
	test("base64url: padding-free, url-safe alphabet, all residues", function()
		for len = 0, 12 do
			local s = {};
			for i = 1, len do s[i] = string.char((i * 37 + len * 11) % 256); end
			local raw = table.concat(s);
			local enc = B64.Encode(raw);
			ok(not enc:find("[=+/]"), "no padding or + / for length " .. len);
			eq(B64.Decode(enc), raw, "round trip length " .. len);
		end
		ok(B64.Decode("a") == nil, "a lone character is not valid base64url");
	end);

	test("JSON: strings with unicode, escapes and nesting survive a round trip", function()
		local src = '["\\u00e9\\u4e2d","line\\nbreak","q\\"uote",[1,2,[3]],{"a":null}]';
		local v = assert(J.Decode(src));
		local enc = assert(J.Encode(v));
		local v2 = assert(J.Decode(enc));
		eq(J.Encode(v2), enc, "stable after one normalisation");
		ok(J.Decode("[1,") == nil, "truncated JSON refused");
		ok(J.Decode('{"a":1,}') == nil, "trailing comma refused");
	end);

	test("UTF-16 length accounting (the site counts UTF-16 units)", function()
		eq(Utf8.Len16("abc"), 3);
		eq(Utf8.Len16("\195\169"), 1);
		eq(Utf8.Len16("\240\159\152\128"), 2, "astral code point = 2 units");
		ok(Utf8.Validate("ok") and not Utf8.Validate("\255"), "validation");
	end);
end
