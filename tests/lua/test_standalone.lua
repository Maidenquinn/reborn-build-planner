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


	test("jewelry: local coefficients use honest base units without requiring the game catalogue", function()
		local j = H.loadAddon({ only = { "JewelryEffects.lua" } });
		j.GeneratedJewelryMechanics = { items = {
			accuria = { slot = "ring", behavior = "damage", base = 0.17 },
			blackhand = { slot = "trinket", behavior = "crit_damage", base = 0.195 }
		} };
		local item = assert(j.JewelryEffects.Sections("accuria", "ring", true));
		eq(item[1].lines[1].text, "17 % de dégâts supplémentaires.", "effect first in plain language");
		eq(item[2].lines[1].text, "Dégâts : 17 %", "reference value accurately labelled");
		ok(item[2].lines[2].text:find("Ce n'est pas", 1, true), "not represented as an actual run value");
		eq(j.JewelryEffects.Sections("accuria", "trinket", true), nil, "wrong slot cannot match");
		eq(j.JewelryEffects.Sections("none", "ring", true), nil, "unknown must stay unavailable");
		j.GeneratedJewelryMechanics.items.blooddrinker = { slot = "ring", behavior = "lifesteal", base = 0.01 };
		local blood = j.JewelryEffects.Sections("blooddrinker", "ring", true);
		eq(blood[1].lines[1].text, "1 % des dégâts que tu infliges te soignent.", "lifesteal is explained in concrete gameplay language");
	end);

	test("jewelry: supplementary passive and conditional effects remain sourced and labelled", function()
		local j = H.loadAddon({ only = { "JewelryEffects.lua" } });
		j.GeneratedJewelryMechanics = { items = {
			accuria = {
				slot = "ring", behavior = "damage", base = 0.17,
				effects = { { "crit", 0.04 }, { "regen", 2.5 } },
				specials = { { "on_hit", 0.18 }, { "jump", 3 } }
			}
		} };
		local e = j.JewelryEffects.Sections("accuria", "ring", true);
		eq(e[3].title, "Autres effets déclarés");
		eq(e[3].lines[1].text, "Chance de critique: 4 %");
		eq(e[3].lines[2].text, "Régénération: 2,5");
		eq(e[4].title, "Effets conditionnels");
		eq(e[4].lines[1].text, "on_hit: 0,18");
		ok(e[4].lines[3].text:find("interprétation dépend du jeu", 1, true));
	end);

	test("jewelry: live text is read only for an exact unique identity during an active run", function()
		local snapshots = {
			AZS_RUN = { ph = "playing" }, AZS_ZONE = { hub = 0 },
			AZS_GEAR = { { name = "Band of Accuria", slot = "ring", text = "Game-provided effect" } }
		};
		local j = H.loadAddon({ only = { "JewelryEffects.lua" }, extra = snapshots });
		local candidates = { { key = "accuria" } };
		local catalog = {
			FindByName = function(self, kind, name, lang)
				return kind == "rings" and name == "Band of Accuria" and candidates or {};
			end
		};
		local e = j.JewelryEffects;
		eq(e.LiveSections(catalog, "accuria", "ring", false)[1].lines[1].text, "Game-provided effect");
		eq(e.LiveSections(catalog, "blackhand", "trinket", false), nil);
		candidates = { { key = "accuria" }, { key = "other" } };
		eq(e.LiveSections(catalog, "accuria", "ring", false), nil, "ambiguous names never match");
		candidates = { { key = "accuria" } };
		snapshots.AZS_ZONE.hub = 1;
		eq(e.LiveSections(catalog, "accuria", "ring", false), nil, "hub cannot reuse old snapshot");
		snapshots.AZS_ZONE.hub = 0; snapshots.AZS_RUN.ph = "ready";
		eq(e.LiveSections(catalog, "accuria", "ring", false), nil, "no run, no live text");
	end);

	test("UTF-16 length accounting (the site counts UTF-16 units)", function()
		eq(Utf8.Len16("abc"), 3);
		eq(Utf8.Len16("\195\169"), 1);
		eq(Utf8.Len16("\240\159\152\128"), 2, "astral code point = 2 units");
		ok(Utf8.Validate("ok") and not Utf8.Validate("\255"), "validation");
	end);
end
