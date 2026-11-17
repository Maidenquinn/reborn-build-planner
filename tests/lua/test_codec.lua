-- Lot 2: codec tests on the REAL modules under Lua 5.1, cross-checked against the official planner's own
-- encoder/decoder (golden.json, cross.json produced by Node from the snapshot asset).
return function(H)
	local eq, ok, no, test = H.eq, H.ok, H.no, H.test;
	-- issue(preview.issues | report, code, path): works on the codec's {list=...} and on model reports
	local function issue(rep, code, path, msg) return H.issue(rep.list and { issues = rep.list } or rep, code, path, msg); end
	local ns = H.loadAddon({ time = function() return 1700000000; end });
	local cat = ns.Catalog.New(ns.GeneratedCatalog);
	local BM, S, U, J, Utf8, B64, C = ns.BuildModel, ns.Storage, ns.Util, ns.Json, ns.Utf8, ns.Base64Url, ns.PlannerCodec;
	local DEF = BM.DEFAULT_LABELS;
	local function now() return 1700000000; end

	local function loadJson(rel)
		local v, err = J.Decode(H.readFile(H.root .. "/tests/fixtures/codec/" .. rel), { maxBytes = 8000000, maxDepth = 12, maxNodes = 3000000 });
		assert(v, "cannot read " .. rel .. ": " .. tostring(err and err.message));
		return v;
	end
	local function unb64(s) return assert(B64.Decode(s)); end
	local function arr(t) return J.Array(t); end
	local function code(array) return C.PREFIX .. B64.Encode(assert(J.Encode(array))); end
	local function codeOfJson(text) return C.PREFIX .. B64.Encode(text); end

	-- site plan -> our model (labels equal to the default are stored as "")
	local function toModel(plan, id)
		local b = assert(BM.New({ id = id or "t", name = plan.name, class = plan.cls, talents = plan.talents }, cat));
		for p = 1, 4 do
			local src, ph = plan.phases[p], b.phases[p];
			ph.label = (src.label == DEF[p]) and "" or src.label;
			for _, k in ipairs(src.spells) do ph.spells[#ph.spells + 1] = { key = k, mode = "acquire" }; end
			for _, k in ipairs(src.banish) do ph.banish[#ph.banish + 1] = k; end
			for i = 1, 4 do ph.rings[i], ph.trinkets[i], ph.amulets[i] = src.rings[i], src.trinkets[i], src.amulets[i]; end
			for k, v in pairs(src.stats) do ph.stats[k] = v; end
			ph.notes, ph.link = src.notes, src.link;
		end
		return b;
	end
	local function keysOf(goals) local o = {}; for i, g in ipairs(goals) do o[i] = g.key; end return o; end
	local function list(t) local o = {}; for i = 1, #t do o[i] = t[i]; end return o; end
	-- does `build` say what the site's decoded plan says?
	local function sameAsSite(build, sp, tag)
		eq(build.name, sp.name, tag .. " name");
		eq(build.class, sp.cls, tag .. " class");
		eq(build.talents, sp.talents, tag .. " talents");
		for p = 1, 4 do
			local a, s = build.phases[p], sp.phases[p];
			eq(a.label == "" and DEF[p] or a.label, s.label, tag .. " label " .. p);
			eq(keysOf(a.spells), list(s.spells), tag .. " spells " .. p);
			eq(a.banish, list(s.banish), tag .. " banish " .. p);
			eq(a.rings, list(s.rings), tag .. " rings " .. p);
			eq(a.trinkets, list(s.trinkets), tag .. " trinkets " .. p);
			eq(a.amulets, list(s.amulets), tag .. " amulets " .. p);
			local st = {};
			for k, v in pairs(s.stats) do st[k] = v; end
			eq(a.stats, st, tag .. " stats " .. p);
			eq(a.notes, s.notes, tag .. " notes " .. p);
			eq(a.link, s.link, tag .. " link " .. p);
		end
	end

	-- ------------------------------------------------------------------ primitives
	test("UTF-8 validation is strict", function()
		ok(Utf8.Validate("plain \195\169 \226\154\148 \240\159\152\128"));
		for _, bad in ipairs({ "\192\128", "\237\160\128", "\255", "\195", "\226\154", "\240\128\128\128", "\244\144\128\128", "\128" }) do
			no(Utf8.Validate(bad), "must refuse " .. H.fmt(bad));
		end
	end);

	test("UTF-16 length, slicing and trim equal JavaScript's", function()
		local c = loadJson("cross.json");
		for _, u in ipairs(c.utf16) do
			local s = unb64(u.text);
			eq(Utf8.Len16(s), u.length, "length");
			for k, b in pairs(u.slices) do
				eq((Utf8.Slice16(s, tonumber(k))), unb64(b), "slice " .. k .. " of " .. H.fmt(s));
			end
		end
		for _, t in ipairs(c.spaces) do
			eq(Utf8.Trim(unb64(t.text)), unb64(t.trimmed), "trim " .. H.fmt(unb64(t.text)));
		end
		local s, cutPair = Utf8.Slice16("a\240\159\152\128b", 2);
		eq(s, "a\239\191\189", "a cut through a surrogate pair leaves U+FFFD");
		ok(cutPair);
	end);

	test("base64url: encode, forgiving decode, refusals", function()
		for n = 0, 40 do
			local s = {};
			for i = 1, n do s[i] = string.char((i * 37 + n * 11) % 256); end
			s = table.concat(s);
			local e = B64.Encode(s);
			no(e:find("[=+/]"), "no padding, url alphabet");
			eq(B64.Decode(e), s);
			eq(B64.Decode(e .. string.rep("=", (4 - #e % 4) % 4)), s, "padding accepted");
			eq(B64.Decode((e:gsub("%-", "+"):gsub("_", "/"))), s, "standard alphabet accepted like atob");
		end
		eq(B64.Decode(" YW Jj\n"), "abc", "ASCII whitespace ignored");
		eq((B64.Decode("YWJj!")), nil);
		eq((B64.Decode("YWJjZ")), nil, "length % 4 == 1");
		eq((B64.Decode("YW=j")), nil, "padding in the middle");
		eq((B64.Decode(string.rep("A", 100), 50)), nil, "too long");
		eq((B64.Decode(5)), nil);
	end);

	test("JSON decoder: strict grammar and limits", function()
		local function bad(text, code, limits)
			local v, err = J.Decode(text, limits);
			eq(v, nil, "must refuse " .. H.fmt(text));
			if code then eq(err.code, code, H.fmt(text)); end
		end
		for _, t in ipairs({ "01", "1.", ".5", "-", "+1", "NaN", "Infinity", "[1,]", "[,1]", "{\"a\":1,}", "[1 2]", "'a'", "\"a", "[1]x", "nul", "tru",
			"// c\n1", "/* c */1", "{\"a\" 1}", "{1:2}", "[", "{", "1e", "1e+", "--1", "\"\\x\"", "\"\\u12\"", "\"a\nb\"", "\"a\1b\"", "" }) do
			bad(t);
		end
		bad("1e999", "BAD_NUMBER");
		bad("[[[[[[[[[1]]]]]]]]]", "TOO_DEEP", { maxDepth = 8 });
		bad(string.rep("[", 2000), "TOO_DEEP");
		bad("[" .. string.rep("1,", 6000) .. "1]", "TOO_MANY_NODES");
		bad(string.rep(" ", 100), "BAD_SYNTAX", nil);
		bad("[1]", "TOO_LARGE", { maxBytes = 2 });
		eq(J.Decode("  [1, 2.5, -3e2, true, false, null, \"x\", {\"a\":[]}]  ")[3], -300);
		local v = J.Decode("[null,{\"a\":1,\"a\":2}]");
		ok(v[1] == J.null);
		eq(v[2].a, 2, "duplicate key: last wins, like JavaScript");
		ok(J.IsArray(v) and J.IsObject(v[2]));
		eq(J.Decode("\"\\ud83d\\ude00\""), "\240\159\152\128", "surrogate pair");
		eq(J.Decode("\"\\ud800x\""), "\239\191\189x", "lone surrogate becomes U+FFFD");
		eq(J.Decode("\"\\u00e9\\n\\/\""), "\195\169\n/");
		eq(J.Decode("0"), 0);
		eq(J.Decode("-0.5e1"), -5);
		eq(J.Decode("123456789012345678901234567890"), 1.2345678901234568e29);
	end);

	test("JSON encoder equals JSON.stringify (numbers and strings)", function()
		local c = loadJson("cross.json");
		for _, n in ipairs(c.numberCorpus) do
			eq(J.FormatNumber(n.value), n.text, "number " .. n.text);
		end
		for _, s in ipairs(c.stringCorpus) do
			eq(J.Quote(s.value), s.json, "string " .. s.json);
		end
		eq(J.Encode(arr({ 1, "a", J.null, true, arr({}), arr({ 2, arr({ "x" }) }) })), "[1,\"a\",null,true,[],[2,[\"x\"]]]");
		local t, err = J.Encode(arr({ 0 / 0 }));
		eq(t, nil);
		t, err = J.Encode(arr({ "\255" }));
		eq(err.code, "INVALID_UTF8");
		t, err = J.Encode(arr({ function() end }));
		eq(err.code, "UNSUPPORTED");
	end);

	-- ------------------------------------------------------------------ official golden vectors
	test("golden vectors: exact code equality and semantic decoding", function()
		local g = loadJson("golden.json");
		eq(#g.vectors, 8);
		for _, v in ipairs(g.vectors) do
			local model = toModel(v.plan, v.id);
			local got, rep = C.Encode(model, cat);
			if not got and v.id == "stats_indexes" then
				ok(rep.needsConfirmation, "12.34 must be announced as rounded by the site");
				got, rep = C.Encode(model, cat, { acceptLosses = true });
			end
			ok(got ~= nil, v.id .. " export refused: " .. H.fmt(rep and rep.losses));
			eq(got, v.code, v.id .. " exact code");
			local pv = C.Decode(v.code, cat);
			ok(pv.ok, v.id .. " decode");
			eq(pv.status, "ready", v.id);
			sameAsSite(pv.build, v.plan, v.id);
		end
	end);

	test("golden decode cases: same accept/reject, same data where the site keeps it, divergences are the documented ones", function()
		local g = loadJson("golden.json");
		local KEEPS = { other_class_spell_dropped = "WRONG_CLASS", duplicate_spells_collapse = "DUPLICATE_ENTRY", banish_overlap_dropped = "CONFLICT_SPELL_BANISH",
			ring_in_trinket_slot = "WRONG_SLOT", duplicate_ring_hole = "DUPLICATE_PIECE", legend_of_other_class = "WRONG_CLASS" };
		local OTHER = { unknown_class = true, seventh_spell_dropped = true, stats_rounding_and_cap = true, extra_phase_ignored = true };
		local seen = 0;
		for _, d in ipairs(g.decodeCases) do
			local pv = C.Decode(d.input, cat);
			if d.id == "unknown_class" then
				ok(pv.ok and not pv.classKnown and not pv.canActivate, "unknown class: kept, never advised");
				issue(pv.issues, "UNKNOWN_CLASS");
			elseif d.accepted and d.result.plan then
				ok(pv.ok, d.id .. " must decode: " .. H.fmt(pv.issues.list));
				seen = seen + 1;
				if KEEPS[d.id] then
					issue(pv.issues, KEEPS[d.id], nil, d.id);
					eq(pv.status, "needs_repair", d.id);
					no(pv.canActivate, d.id);
				elseif not OTHER[d.id] then
					sameAsSite(pv.build, d.result.plan, d.id);
				end
			elseif d.accepted then
				ok(pv.ok and pv.kind == "talents", d.id .. " talents only");
				eq(pv.talents, d.result.talents, d.id);
			else
				no(pv.ok, d.id .. " must be refused");
			end
		end
		ok(seen >= 15, "plan cases examined: " .. seen);
		-- the divergences, spelled out
		local function case(id) for _, d in ipairs(g.decodeCases) do if d.id == id then return C.Decode(d.input, cat); end end end
		local seventh = case("seventh_spell_dropped");
		eq(#seventh.build.phases[1].spells, 6);
		eq(#seventh.build.phases[1].ext.import.overflow_spells, 1, "the 7th spell is kept aside, not lost");
		local stats = case("stats_rounding_and_cap");
		eq(stats.build.phases[1].stats, { damage = 12.34 }, "exact value kept (the site rounds to 12.3)");
		eq(#stats.build.phases[1].ext.import.rejectedStats, 4, "negative, unknown index, non-numeric and >999 values kept aside");
		local extra = case("extra_phase_ignored");
		eq(#extra.build.ext.import.extraPhases, 1);
		local link = case("link_non_http_dropped");
		eq(link.build.phases[1].link, "");
		eq(link.build.phases[1].ext.import.rejectedLink, "javascript:alert(1)");
		local tal = case("talents_invalid_chars");
		eq(tal.build.talents, "");
		eq(tal.build.ext.import.rejectedTalents, "12a-3");
	end);

	-- ------------------------------------------------------------------ JS <-> Lua cross-check
	test("JavaScript encoder vs Lua encoder: 60 random plans, exact codes; decode and re-encode agree", function()
		local c = loadJson("cross.json");
		eq(#c.cases, 60);
		local reenc = {};
		for _, case in ipairs(c.cases) do
			local model = toModel(case.plan, case.id);
			local got, rep = C.Encode(model, cat);
			ok(got ~= nil, case.id .. " refused: " .. H.fmt(rep and rep.losses));
			ok(rep.lossless, case.id .. " claimed a loss on a plain plan: " .. H.fmt(rep.losses));
			eq(got, case.code, case.id .. " exact code");
			local pv = C.Decode(case.code, cat);
			ok(pv.ok, case.id);
			sameAsSite(pv.build, case.siteDecoded, case.id);
			local again = C.Encode(pv.build, cat);
			eq(again, case.code, case.id .. " JS -> Lua -> JS code is stable");
			reenc[#reenc + 1] = { id = case.id, code = again };
		end
		-- decimals: the encoder does not round; the site's decoder will (reported as a loss)
		for _, case in ipairs(c.encoderOnly) do
			local model = toModel(case.plan, case.id);
			local noAccept, rep = C.Encode(model, cat);
			eq(noAccept, nil, "decimals need confirmation");
			ok(rep.needsConfirmation);
			local got = C.Encode(model, cat, { acceptLosses = true });
			eq(got, case.code, "decimals exact code");
		end
		local out = {};
		for i, r in ipairs(reenc) do out[i] = "{\"id\":" .. J.Quote(r.id) .. ",\"code\":" .. J.Quote(r.code) .. "}"; end
		local fh = assert(io.open(H.root .. "/tests/results/lua_reencoded.json", "wb"));
		fh:write("[" .. table.concat(out, ",\n") .. "]\n");
		fh:close();
	end);

	test("link validation matches the site on the reference list", function()
		local c = loadJson("cross.json");
		local diff = {};
		for _, l in ipairs(c.links) do
			if C.LinkOk(l.link) ~= l.accepted then diff[#diff + 1] = l.link; end
		end
		eq(diff, {}, "links where the approximation disagrees with a browser URL parser");
	end);

	-- ------------------------------------------------------------------ decoding behaviour
	local function plan(arrayParts) return code(arr(arrayParts)); end
	local function phase(spells, banish, rings, trinkets, amulets, stats, notes, link, label)
		local a = { label or "", arr(spells or {}), arr(banish or {}), arr(rings or {}), arr(trinkets or {}), arr(amulets or {}), arr(stats or {}), notes or "", link or "" };
		return arr(a);
	end

	test("nothing is dropped silently: unknown keys, wrong class, duplicates, conflicts, overflow", function()
		local c = plan({ 1, "T", "warrior", "", phase({ "whirlwind", "mystery", "death_coil", "whirlwind", "execute", "cleave", "rend" }, { "execute", "bloodrage", "shockwave", "battle_shout" },
			{ "accuria", "accuria", "earthstrike" }, {}, { "legendary:death_coil" }) });
		local pv = C.Decode(c, cat);
		ok(pv.ok);
		eq(pv.status, "needs_repair");
		no(pv.canActivate);
		local ph = pv.build.phases[1];
		eq(keysOf(ph.spells), { "whirlwind", "mystery", "death_coil", "whirlwind", "execute", "cleave" });
		eq(ph.ext.import.overflow_spells, { "rend" });
		eq(ph.banish, { "execute", "bloodrage", "shockwave" });
		eq(ph.ext.import.overflow_banish, { "battle_shout" });
		eq(ph.rings, { "accuria", "accuria", "earthstrike", "" });
		eq(ph.amulets, { "legendary:death_coil", "", "", "" });
		for _, code2 in ipairs({ "UNKNOWN_KEY", "WRONG_CLASS", "DUPLICATE_ENTRY", "CONFLICT_SPELL_BANISH", "DUPLICATE_PIECE", "WRONG_SLOT", "OVERFLOW_PRESERVED" }) do
			issue(pv.issues, code2);
		end
		ok(pv.exportReport.intentLosses >= 5, "a re-export would lose entries and says so");
		for _, it in ipairs(pv.issues.list) do ok(type(it.message) == "string" and it.message ~= "", "every issue is explained"); end
	end);

	test("legendary homonyms: same identifier text, different class, different key", function()
		local function legend(cls, key)
			local pv = C.Decode(plan({ 1, "L", cls, "", phase({}, {}, {}, {}, { key }) }), cat);
			ok(pv.ok);
			return pv;
		end
		local a = legend("warlock", "legendary:death_coil");
		ok(a.canActivate);
		local b = legend("deathknight", "legendary:death_coil");        -- warlock's key on a death knight
		issue(b.issues, "WRONG_CLASS");
		no(b.canActivate);
		ok(legend("deathknight", "legendary:dk_death_coil").canActivate);
	end);

	test("shapes: null phases, abbreviated forms, defaults, fifth phase, extra fields", function()
		local pv = C.Decode(plan({ 1, "A", "warrior" }), cat);
		ok(pv.ok);
		eq(#pv.build.phases, 4);
		for p = 1, 4 do ok(pv.phases[p].empty); end
		pv = C.Decode(plan({ 1, "A", "warrior", "", J.null, J.null, phase({ "cleave" }), J.null }), cat);
		ok(pv.ok);
		eq(pv.phases[3].spells, 1);
		ok(pv.phases[1].empty and pv.phases[2].empty and pv.phases[4].empty);
		pv = C.Decode(plan({ 1, "A", "warrior", "", arr({ "Early Game", arr({ "cleave" }) }) }), cat);
		eq(pv.build.phases[1].label, "", "a label equal to the default is stored as the empty default");
		eq(keysOf(pv.build.phases[1].spells), { "cleave" });
		pv = C.Decode(plan({ 1, "A", "warrior", "", arr({ "Mid Game" }) }), cat);
		eq(pv.build.phases[1].label, "Mid Game", "same text on another phase index is a custom label");
		pv = C.Decode(plan({ 1, "A", "warrior", "", J.null, J.null, J.null, J.null, arr({ "x" }), 7 }), cat);
		eq(pv.build.ext.import.extraPhases, { { "x" }, 7 });
		issue(pv.issues, "EXTRA_DATA_PRESERVED");
		pv = C.Decode(plan({ 1, "A", "warrior", "", arr({ "", arr({}), arr({}), arr({}), arr({}), arr({}), arr({}), "", "", "extra", { 1 } }) }), cat);
		eq(pv.build.phases[1].ext.import.extraFields, { "extra", { 1 } });
	end);

	test("refusals: nothing usable, nothing stored", function()
		local function refused(text, wantCode, label)
			local pv = C.Decode(text, cat);
			no(pv.ok, label or H.fmt(text));
			eq(pv.errorCode, wantCode, label or H.fmt(text));
			ok(pv.issues.errors >= 1);
			eq(pv.build, nil);
		end
		refused("", "EMPTY_INPUT");
		refused("   \n ", "EMPTY_INPUT");
		refused(nil, "EMPTY_INPUT");
		refused("azsb1:!!!!", "BASE64_INVALID");
		refused("azsb1:A", "BASE64_INVALID");
		refused(code(arr({ 2, "x", "warrior", "" })), "UNSUPPORTED_VERSION", "future version");
		refused(code(arr({ 0, "x", "warrior", "" })), "UNSUPPORTED_VERSION", "version 0");
		refused(code(arr({ "1", "x", "warrior" })), "NOT_A_PLAN");
		refused(codeOfJson("{\"a\":1}"), "NOT_A_PLAN");
		refused(codeOfJson("\"text\""), "NOT_A_PLAN");
		refused(codeOfJson("[1,\"x\""), "JSON_INVALID", "truncated JSON");
		refused(codeOfJson("[1,\"x\",\"warrior\"]garbage"), "JSON_INVALID", "trailing garbage");
		refused(code(arr({ 1, "x", "" })), "MISSING_CLASS");
		refused(code(arr({ 1, "x" })), "MISSING_CLASS");
		refused(code(arr({ 1, 5, "warrior" })), "TYPE_MISMATCH", "name is a number");
		refused(code(arr({ 1, "x", "warrior", 5 })), "TYPE_MISMATCH");
		refused(code(arr({ 1, "x", "warrior", "", 5 })), "TYPE_MISMATCH", "phase is a number");
		refused(code(arr({ 1, "x", "warrior", "", arr({ "", "cleave" }) })), "TYPE_MISMATCH", "spells is a string");
		refused(code(arr({ 1, "x", "warrior", "", arr({ "", arr({ 5 }) }) })), "TYPE_MISMATCH", "spell key is a number");
		refused(code(arr({ 1, "x", "warrior", "", arr({ "", arr({}), arr({}), arr({ 1 }) }) })), "TYPE_MISMATCH", "ring is a number");
		refused(C.PREFIX .. B64.Encode("[1,\"\195\"]"), "INVALID_UTF8", "invalid UTF-8 bytes");
		refused(C.PREFIX .. B64.Encode("[1,\"\237\160\128\"]"), "INVALID_UTF8", "encoded surrogate");
		refused(codeOfJson(string.rep("[", 12) .. string.rep("]", 12)), "JSON_INVALID", "nested too deep");
		refused(codeOfJson("[1,\"x\",\"warrior\",\"\"," .. string.rep("null,", 6000) .. "null]"), "JSON_INVALID", "too many values");
		refused(C.PREFIX .. string.rep("A", C.LIMITS.encodedChars + 1), "INPUT_TOO_LARGE");
		refused(C.PREFIX .. B64.Encode(string.rep(" ", C.LIMITS.decodedBytes + 1) .. "[1]"), "PAYLOAD_TOO_LARGE");
		refused("ftp://azreborn.com/planner/warrior?p=abc", "URL_SCHEME_UNSUPPORTED");
		refused("https://azreborn.com/planner/warrior", "URL_NO_PAYLOAD");
		refused("https://azreborn.com/planner/warrior?x=1", "URL_NO_PAYLOAD");
		refused("https://azreborn.com/planner/warrior?b=12a", "TALENTS_INVALID");
		refused("\255\254", "INVALID_UTF8");
	end);

	test("accepted spellings of the input", function()
		local good = code(arr({ 1, "N\195\169", "warrior", "", phase({ "cleave" }) }));
		local payload = good:sub(7);
		for _, input in ipairs({ good, "azsb1." .. payload, "AZSB1:" .. payload, payload, "  " .. good .. "\n", good .. string.rep("=", (4 - #payload % 4) % 4),
			"https://azreborn.com/planner/warrior?p=" .. payload, "https://azreborn.com/planner/warrior?x=1&p=" .. payload .. "#frag",
			"http://example.org/other?p=" .. payload }) do
			local pv = C.Decode(input, cat);
			ok(pv.ok, H.fmt(input));
			eq(pv.build.name, "N\195\169");
		end
		local pv = C.Decode("https://azreborn.com/planner/warrior?p=" .. payload, cat);
		ok(pv.official);
		pv = C.Decode("https://evil.example/planner/warrior?p=" .. payload, cat);
		ok(pv.ok and not pv.official);
		issue(pv.issues, "NON_OFFICIAL_HOST");
		eq(C.Decode("https://azreborn.com/planner/warrior?p=" .. payload:gsub("%-", "%%2D"), cat).ok, true, "percent-encoding is decoded");
		pv = C.Decode(C.PREFIX .. B64.Encode("\239\187\191[1,\"b\",\"warrior\"]"), cat);
		ok(pv.ok, "a BOM is dropped like a TextDecoder does");
	end);

	test("talents links: class from the path, or an explicit class is needed", function()
		local pv = C.Decode("https://azreborn.com/planner/warrior?b=10203-000-0110", cat);
		ok(pv.ok and pv.kind == "talents");
		eq(pv.talents, "10203-000-0110");
		eq(pv.class, "warrior");
		no(pv.needsClass);
		pv = C.Decode("https://azreborn.com/planner/mage/?b=1-2-3", cat);
		eq(pv.class, "mage");
		pv = C.Decode("https://azreborn.com/planner?b=1-2-3", cat);
		ok(pv.ok and pv.needsClass and pv.class == nil);
		pv = C.Decode("10203-000-0110", cat);
		ok(pv.ok and pv.kind == "talents" and pv.needsClass);
		pv = C.Decode("12345", cat);                         -- digits without a dash are not a talent string
		no(pv.ok);
		pv = C.Decode("https://azreborn.com/planner/warrior?b=", cat);
		ok(pv.ok and pv.talents == "", "an empty b= is an empty talent string, as on the site");
		pv = C.Decode("1--2", cat);
		no(pv.ok);
	end);

	test("text limits are the site's UTF-16 limits and truncation is visible", function()
		local name59 = string.rep("a", 59) .. "\240\159\152\128";      -- 61 UTF-16 units
		local pv = C.Decode(plan({ 1, name59, "warrior" }), cat);
		eq(pv.build.name, string.rep("a", 59) .. "\239\191\189", "cut through the pair: U+FFFD, like the site");
		issue(pv.issues, "TRUNCATED", "name");
		local name60 = string.rep("a", 58) .. "\240\159\152\128";       -- exactly 60 units
		pv = C.Decode(plan({ 1, name60, "warrior" }), cat);
		eq(pv.build.name, name60);
		no(pv.issues.list[1], "no warning at the limit");
		local notes = string.rep("\240\159\152\128", 1000);              -- 2000 units
		pv = C.Decode(plan({ 1, "n", "warrior", "", phase({}, {}, {}, {}, {}, {}, notes) }), cat);
		eq(pv.build.phases[1].notes, notes);
		pv = C.Decode(plan({ 1, "n", "warrior", "", phase({}, {}, {}, {}, {}, {}, notes .. "x") }), cat);
		eq(pv.build.phases[1].notes, notes);
		issue(pv.issues, "TRUNCATED");
		pv = C.Decode(plan({ 1, "n", "warrior", "", phase({}, {}, {}, {}, {}, {}, "", "", string.rep("L", 30)) }), cat);
		eq(pv.build.phases[1].label, string.rep("L", 24));
		pv = C.Decode(plan({ 1, "  \226\128\131padded\227\128\128 ", "warrior" }), cat);
		eq(pv.build.name, "padded", "JavaScript trim semantics (em space, ideographic space)");
	end);

	test("stats: base-zero indexes, exact values, odd entries are kept aside", function()
		local pv = C.Decode(plan({ 1, "s", "warrior", "", phase({}, {}, {}, {}, {}, { arr({ 0, 50 }), arr({ 2, 12.34 }), arr({ 10, 5 }), arr({ 11, 3 }), arr({ 1, 0 }), arr({ 3, 1000 }), 7, arr({ 4, "x" }), arr({ 0, 60 }) }) }), cat);
		local st = pv.build.phases[1].stats;
		eq(st, { damage = 60, crit = 12.34, gold = 5 }, "last value wins, exact decimals");
		eq(#pv.build.phases[1].ext.import.rejectedStats, 5);
		ok(pv.issues.warnings >= 5);
	end);

	test("a link that is not http(s) is kept aside, never active", function()
		for _, l in ipairs({ "javascript:alert(1)", "ftp://a.b/c", "https://", "http://a b", "data:text/html,x" }) do
			local pv = C.Decode(plan({ 1, "l", "warrior", "", phase({}, {}, {}, {}, {}, {}, "", l) }), cat);
			eq(pv.build.phases[1].link, "", l);
			eq(pv.build.phases[1].ext.import.rejectedLink, l);
			issue(pv.issues, "LINK_REJECTED");
		end
		local pv = C.Decode(plan({ 1, "l", "warrior", "", phase({}, {}, {}, {}, {}, {}, "", "https://azreborn.com/planner/warrior") }), cat);
		eq(pv.build.phases[1].link, "https://azreborn.com/planner/warrior");
	end);

	-- ------------------------------------------------------------------ two-step import
	local function handle() return S.Open(nil, { catalog = cat, now = now }); end
	local good = code(arr({ 1, "Imported", "warrior", "10-0-0", phase({ "whirlwind", "execute" }, { "rend" }, { "accuria", "", "quick_strike" }) }));
	local conflicted = code(arr({ 1, "Conflicted", "warrior", "", phase({ "whirlwind" }, { "whirlwind" }) }));

	test("preview changes nothing; commit adds a NEW build, never activates, never overwrites", function()
		local h = handle();
		local existing = h:Create({ name = "mine", class = "warrior" });
		ok(h:SetActive("warrior", existing));
		local snap = U.DeepCopy(h.db);
		local pv = C.PreviewImport and C.Decode(good, cat);
		ok(pv.ok);
		ok(H.deepeq(h.db, snap), "preview must not touch storage");
		eq(pv.name, "Imported");
		eq(pv.class, "warrior");
		eq(pv.status, "ready");
		ok(pv.canActivate);
		eq(pv.phases[1].spells, 2);
		eq(pv.source.text, good);
		local id, rep = C.CommitImport(h, pv);
		ok(id and id ~= existing);
		eq(h:Get(id).name, "Imported");
		eq(h:Get(id).revision, 1);
		eq(h:GetActive("warrior"), existing, "an import never becomes active by itself");
		eq(h:Get(existing).name, "mine");
		eq(#h:List("warrior"), 2);
		local id2 = C.CommitImport(h, pv);
		ok(id2 and id2 ~= id, "importing twice gives two builds");
		pv.build.name = "mutated after preview";
		eq(h:Get(id).name, "Imported");
	end);

	test("a build with conflicts can be stored for repair but not activated", function()
		local h = handle();
		local pv = C.Decode(conflicted, cat);
		eq(pv.status, "needs_repair");
		local id = C.CommitImport(h, pv);
		ok(id, "stored");
		eq(h:Get(id).phases[1].banish, { "whirlwind" }, "the conflicting entry is still there");
		local r, err = h:SetActive("warrior", id);
		eq(r, nil);
		eq(err.code, "NOT_ACTIVATABLE");
		eq(h:GetActive("warrior"), nil);
		-- repairing it makes it activatable
		local fixed = BM.RemoveBanish(h:Get(id), 1, "whirlwind", cat);
		ok(h:Update(id, fixed));
		ok(h:SetActive("warrior", id));
		-- an unknown class is stored but never activated
		local un = C.CommitImport(h, C.Decode(code(arr({ 1, "F", "necromancer", "" })), cat));
		ok(un);
		r, err = h:SetActive("necromancer", un);
		eq(err.code, "NOT_ACTIVATABLE");
	end);

	test("refused imports and refused commits change nothing", function()
		local h = handle();
		h:Create({ name = "a", class = "warrior" });
		local snap = U.DeepCopy(h.db);
		local bad = C.Decode("azsb1:garbage!", cat);
		local id, err = C.CommitImport(h, bad);
		eq(id, nil);
		eq(err.code, "PREVIEW_NOT_OK");
		id, err = C.CommitImport(h, nil);
		eq(err.code, "PREVIEW_NOT_OK");
		ok(H.deepeq(h.db, snap));
		local ro = S.Open({ schema = 99 }, { catalog = cat, now = now });
		id, err = C.CommitImport(ro, C.Decode(good, cat));
		eq(err.code, "READ_ONLY");
		local full = handle();
		for i = 1, S.LIMITS.builds do full:Create({ name = "b" .. i, class = "mage" }); end
		local before = U.DeepCopy(full.db);
		id, err = C.CommitImport(full, C.Decode(good, cat));
		eq(id, nil);
		eq(err.code, "LIBRARY_FULL");
		ok(H.deepeq(full.db, before));
	end);

	test("talents-only import needs a class and adds a new build", function()
		local h = handle();
		local pv = C.Decode("https://azreborn.com/planner?b=1-2-3", cat);
		local id, err = C.CommitImport(h, pv);
		eq(err.code, "NEED_CLASS");
		eq(h:Counts().builds, 0);
		id = C.CommitImport(h, pv, { class = "MAGE", name = "Frost talents" });
		ok(id);
		eq(h:Get(id).class, "mage");
		eq(h:Get(id).talents, "1-2-3");
		eq(h:Get(id).name, "Frost talents");
		id = C.CommitImport(h, C.Decode("https://azreborn.com/planner/rogue?b=0-1-2", cat));
		eq(h:Get(id).class, "rogue");
		eq(h:Get(id).name, "Imported build");
	end);

	-- ------------------------------------------------------------------ export
	test("export reports what the official format cannot carry, before exporting", function()
		local b = assert(BM.New({ id = "e", name = "Export", class = "warrior" }, cat));
		b = BM.AddSpell(b, 1, "whirlwind", { mode = "rank", rank = 3 }, cat);
		b = BM.AddSpell(b, 1, "execute", { mode = "unlimited" }, cat);
		b = BM.AddSpell(b, 1, "cleave", nil, cat);
		b.ext.futureField = { 1 };
		b.phases[2].ext.note = "x";
		local rep = C.PlanExport(b, cat);
		ok(rep.ok);
		no(rep.lossless);
		local byCode = {};
		for _, l in ipairs(rep.losses) do byCode[l.code] = (byCode[l.code] or 0) + 1; end
		eq(byCode.GOAL_MODE_NOT_REPRESENTABLE, 2);
		eq(byCode.EXT_NOT_REPRESENTABLE, 2);
		eq(byCode.METADATA_OMITTED, 1);
		eq(rep.intentLosses, 4);
		local out, rep2 = C.Encode(b, cat);
		eq(out, nil, "refused until the losses are accepted");
		ok(rep2.needsConfirmation);
		out, rep2 = C.Encode(b, cat, { acceptLosses = true });
		ok(out and out:sub(1, 6) == "azsb1:");
		-- only metadata differs: no confirmation needed, and it is not presented as lossless when it is not
		local clean = assert(BM.New({ id = "c", name = "Clean", class = "warrior" }, cat));
		clean = BM.AddSpell(clean, 1, "cleave", nil, cat);
		local code3, rep3 = C.Encode(clean, cat);
		ok(code3 ~= nil and rep3.lossless);
		eq(rep3.intentLosses, 0);
		ok(rep3.losses[1].severity == "info", "metadata is reported as information");
	end);

	test("export: entries the site would drop, truncations, ranges, links", function()
		local raw = U.DeepCopy(assert(BM.New({ id = "x", name = string.rep("n", 61), class = "warrior", talents = "abc" }, cat)));
		raw.phases[1].spells = { { key = "whirlwind", mode = "acquire" }, { key = "death_coil", mode = "acquire" }, { key = "zzz", mode = "acquire" }, { key = "whirlwind", mode = "acquire" } };
		raw.phases[1].banish = { "whirlwind" };
		raw.phases[1].rings = { "accuria", "earthstrike", "", "" };
		raw.phases[1].notes = string.rep("n", 2001);
		raw.phases[1].link = "javascript:x";
		raw.phases[1].label = string.rep("l", 30);
		raw.phases[1].stats = { damage = 999, crit = 12.34, gold = 0, speed = 5 };
		local b = BM.Normalize(raw, cat);
		local rep = C.PlanExport(b, cat);
		local seen = {};
		for _, l in ipairs(rep.losses) do seen[l.code] = (seen[l.code] or 0) + 1; end
		for _, want in ipairs({ "SITE_TRUNCATES", "SITE_DROPS_TALENTS", "SITE_DROPS_KEY", "SITE_DROPS_DUPLICATE", "SITE_DROPS_BANISH_OVERLAP", "SITE_DROPS_LINK",
			"SITE_ROUNDS_STAT", "STAT_ZERO_OMITTED" }) do
			ok(seen[want], "expected loss " .. want .. " in " .. H.fmt(seen));
		end
		local out = assert(C.Encode(b, cat, { acceptLosses = true }));
		local back = C.Decode(out, cat);
		eq(#back.build.name, 60, "name cut to 60 as announced");
		eq(back.build.phases[1].stats.crit, 12.34, "kept exactly here; the site rounds on ITS import, which was announced");
		eq(back.build.phases[1].stats.gold, nil);
		eq(back.build.phases[1].link, "");
		eq(back.build.talents, "");
		-- unknown class: the site would refuse the whole build, so even accepted losses cannot export it
		local u = assert(BM.New({ id = "u", name = "u", class = "necromancer" }, cat));
		local o, r = C.Encode(u, cat, { acceptLosses = true });
		eq(o, nil);
		ok(r.fatal);
		-- invalid build
		local inv = U.DeepCopy(b);
		inv.phases = {};
		o, r = C.Encode(inv, cat, { acceptLosses = true });
		eq(o, nil);
		-- no catalogue: still encodes, says keys were not checked
		local c2 = C.PlanExport(assert(BM.New({ id = "n", name = "n", class = "warrior" })), nil);
		ok(c2.ok);
		local found = false;
		for _, l in ipairs(c2.losses) do if l.code == "CATALOG_UNAVAILABLE" then found = true; end end
		ok(found);
	end);

	test("roundtrip Lua -> code -> Lua keeps phases, priorities, alternatives, talents, notes, stats and links", function()
		local b = assert(BM.New({ id = "r", name = "Round \195\169\240\159\152\128", class = "mage", talents = "1-2-3" }, cat));
		local steps = { { "spells", "frostbolt" }, { "spells", "fireball" }, { "spells", "arcane_blast" } };
		b = BM.AddSpell(b, 1, "frostbolt", nil, cat);
		b = BM.AddSpell(b, 1, "fireball", nil, cat);
		b = BM.AddBanish(b, 1, "frost_nova", cat);
		b = BM.SetSlot(b, 1, "rings", 1, "accuria", cat);
		b = BM.SetSlot(b, 1, "rings", 4, "quick_strike", cat);
		b = BM.SetSlot(b, 3, "trinkets", 2, "earthstrike", cat);
		b = BM.SetSlot(b, 3, "amulets", 3, "dragonwrath", cat);
		b = BM.SetStat(b, 1, "crit", 12.5, cat);
		b = BM.SetNotes(b, 4, "ligne 1\nligne 2 \"q\" \\", cat);
		b = BM.SetLink(b, 4, "https://azreborn.com/planner/mage", cat);
		b = BM.SetLabel(b, 3, "Final", cat);
		local out, rep = C.Encode(b, cat);
		ok(out, H.fmt(rep.losses));
		local pv = C.Decode(out, cat);
		ok(pv.ok and pv.status == "ready");
		for _, f in ipairs({ "name", "class", "talents" }) do eq(pv.build[f], b[f], f); end
		for p = 1, 4 do
			local x, y = pv.build.phases[p], b.phases[p];
			for _, f in ipairs({ "label", "banish", "rings", "trinkets", "amulets", "stats", "notes", "link" }) do eq(x[f], y[f], "phase " .. p .. " " .. f); end
			eq(x.spells, y.spells, "phase " .. p .. " spells (acquire goals)");
		end
		eq(C.Encode(pv.build, cat), out, "stable");
		-- Lua-made codes for the browser-side check (tools/verify_reencoded.mjs decodes them with the site's own code)
		local function siteView(x)
			local v = { name = x.name, cls = x.class, talents = x.talents, phases = {} };
			for p = 1, 4 do
				local ph = x.phases[p];
				v.phases[p] = { label = ph.label == "" and DEF[p] or ph.label, spells = keysOf(ph.spells), banish = ph.banish, rings = ph.rings,
					trinkets = ph.trinkets, amulets = ph.amulets, stats = ph.stats, notes = ph.notes, link = ph.link };
			end
			return v;
		end
		local function ser(v)
			if type(v) == "string" then return J.Quote(v); end
			if type(v) == "number" then return J.FormatNumber(v); end
			if type(v) == "boolean" then return tostring(v); end
			local parts = {};
			if #v > 0 or next(v) == nil then
				for i = 1, #v do parts[i] = ser(v[i]); end
				return "[" .. table.concat(parts, ",") .. "]";
			end
			for _, k in ipairs(U.SortedKeys(v)) do parts[#parts + 1] = J.Quote(k) .. ":" .. ser(v[k]); end
			return "{" .. table.concat(parts, ",") .. "}";
		end
		local origin = { { id = "roundtrip", code = out, expect = siteView(b) } };
		local w = assert(BM.New({ id = "w", name = "Warrior \240\159\152\128 \195\169", class = "warrior", talents = "10203-000-0110" }, cat));
		w = BM.AddSpell(BM.AddSpell(w, 1, "whirlwind", nil, cat), 1, "execute", nil, cat);
		w = BM.SetSlot(w, 2, "amulets", 1, "legendary:cleave", cat);
		w = BM.SetSlot(w, 2, "trinkets", 3, "hoj", cat);
		w = BM.SetStat(BM.SetStat(w, 2, "damage", 50, cat), 2, "speed", 7.5, cat);
		w = BM.SetNotes(w, 2, "ligne 1\nligne 2\t\"q\" \\ \226\128\168 end", cat);
		origin[#origin + 1] = { id = "warrior-legend", code = assert(C.Encode(w, cat)), expect = siteView(w) };
		local bare = assert(BM.New({ id = "z", name = "", class = "druid" }, cat));
		origin[#origin + 1] = { id = "empty-druid", code = assert(C.Encode(bare, cat)), expect = siteView(bare) };
		local items = {};
		for i, o in ipairs(origin) do items[i] = "{\"id\":" .. J.Quote(o.id) .. ",\"code\":" .. J.Quote(o.code) .. ",\"expect\":" .. ser(o.expect) .. "}"; end
		local fh = assert(io.open(H.root .. "/tests/results/lua_origin.json", "wb"));
		fh:write("[" .. table.concat(items, ",\n") .. "]\n");
		fh:close();
	end);

	test("no code path executes imported text", function()
		for _, f in ipairs({ "Utf8.lua", "Base64Url.lua", "Json.lua", "PlannerCodec.lua" }) do
			local src = H.readFile(H.root .. "/addon/RebornBuildPlanner/" .. f):gsub("%-%-[^\n]*", "");
			for _, w in ipairs({ "loadstring", "dofile", "loadfile", "%f[%w]load%f[%W]", "setfenv", "getfenv", "require", "RunScript", "pcall%(%s*_G" }) do
				no(src:find(w), f .. " mentions " .. w);
			end
		end
		-- hostile content is only ever data
		local pv = C.Decode(code(arr({ 1, "os.execute('x')", "warrior", "", phase({ "RunScript('x')" }, {}, {}, {}, {}, {}, "]]..loadstring('x')()..[[", "") })), cat);
		ok(pv.ok);
		eq(pv.build.name, "os.execute('x')");
		issue(pv.issues, "UNKNOWN_KEY");
	end);
end
