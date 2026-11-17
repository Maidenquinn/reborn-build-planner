return function(H)
	local eq, ok, no, test, issue, noissue = H.eq, H.ok, H.no, H.test, H.issue, H.noissue;
	local ns = H.loadAddon();
	local cat = ns.Catalog.New(ns.GeneratedCatalog);
	local BM, U = ns.BuildModel, ns.Util;

	local function fresh(class)
		local b, rep = BM.New({ id = "b1", name = "WW", class = class or "warrior" }, cat);
		ok(b ~= nil, "New failed");
		return b;
	end
	-- applies a chain of edits, each must succeed
	local function chain(b, steps)
		for i, s in ipairs(steps) do
			local nb, rep = s(b);
			if not nb then
				H.eq(rep.issues, "step " .. i .. " refused");
				return b;
			end
			b = nb;
		end
		return b;
	end
	local SIX = { "whirlwind", "execute", "cleave", "rend", "bloodthirst", "shockwave" };

	test("create a build", function()
		local b, rep = BM.New({ id = "b1", name = "WW", class = "warrior", talents = "10203-000-0110" }, cat);
		ok(rep.clean);
		eq(b.revision, 1);
		eq(b.catalog, "384db000d5ac311d");
		eq(b.model, 1);
		eq(#b.phases, 4);
		eq(b.phases[1].rings, { "", "", "", "" });
		eq(b.phases[1].amulets, { "", "", "", "" });
		eq(b.phases[1].spells, {});
		eq(b.talents, "10203-000-0110");
		local nb, bad = BM.New({ name = "x", class = "warrior" }, cat);
		eq(nb, nil);
		issue(bad, "INVALID_VALUE", "id");
		nb, bad = BM.New({ id = "x" }, cat);
		eq(nb, nil);
		issue(bad, "INVALID_VALUE", "class");
	end);

	test("clone is independent", function()
		local b = fresh();
		local c = BM.Clone(b);
		ok(H.deepeq(b, c));
		c.phases[1].spells[1] = { key = "x", mode = "acquire" };
		c.name = "other";
		eq(#b.phases[1].spells, 0);
		eq(b.name, "WW");
	end);

	test("editing returns a new build and bumps the revision; the source never changes", function()
		local b = fresh();
		local before = U.DeepCopy(b);
		local nb = BM.SetName(b, "Renamed", cat);
		eq(nb.name, "Renamed");
		eq(nb.revision, 2);
		ok(nb ~= b);
		ok(H.deepeq(b, before), "source mutated");
		local nb2 = BM.AddSpell(nb, 1, "whirlwind", nil, cat);
		eq(nb2.revision, 3);
		eq(nb.revision, 2);
	end);

	test("six wanted spells and three banishes are two separate lists", function()
		local b = fresh();
		local steps = {};
		for _, k in ipairs(SIX) do steps[#steps + 1] = function(x) return BM.AddSpell(x, 1, k, nil, cat); end; end
		b = chain(b, steps);
		eq(#b.phases[1].spells, 6);
		local seventh, rep = BM.AddSpell(b, 1, "shield_slam", nil, cat);
		eq(seventh, nil);
		issue(rep, "TOO_MANY");
		b = chain(b, {
			function(x) return BM.AddBanish(x, 1, "battle_shout", cat); end,
			function(x) return BM.AddBanish(x, 1, "demo_shout", cat); end,
			function(x) return BM.AddBanish(x, 1, "bloodrage", cat); end,
		});
		eq(#b.phases[1].banish, 3);
		eq(#b.phases[1].spells, 6, "banishes consumed a wanted slot");
		local fourth, rep2 = BM.AddBanish(b, 1, "heroic_throw", cat);
		eq(fourth, nil);
		issue(rep2, "TOO_MANY");
		-- removing a banish frees a banish slot only
		local nb = BM.RemoveBanish(b, 1, "demo_shout", cat);
		eq(#nb.phases[1].banish, 2);
		eq(#nb.phases[1].spells, 6);
		ok(BM.Validate(b, cat).clean);
	end);

	test("spell/banish conflicts are refused when created, reported when imported", function()
		local b = BM.AddSpell(fresh(), 1, "whirlwind", nil, cat);
		local x, rep = BM.AddBanish(b, 1, "whirlwind", cat);
		eq(x, nil);
		issue(rep, "CONFLICT_SPELL_BANISH");
		local y, rep2 = BM.AddSpell(b, 1, "whirlwind", nil, cat);
		eq(y, nil);
		issue(rep2, "DUPLICATE_ENTRY");
		-- imported data keeps its conflict (nothing removed silently)
		local raw = U.DeepCopy(b);
		raw.phases[1].banish = { "whirlwind" };
		local imp, irep = BM.Normalize(raw, cat);
		ok(imp ~= nil);
		issue(irep, "CONFLICT_SPELL_BANISH");
		no(irep.clean);
		eq(imp.phases[1].spells[1].key, "whirlwind");
		eq(imp.phases[1].banish, { "whirlwind" });
		-- an unrelated edit and the repair are both allowed on a conflicted build
		local named = BM.SetName(imp, "still editable", cat);
		ok(named ~= nil);
		local fixed, frep = BM.RemoveBanish(imp, 1, "whirlwind", cat);
		ok(fixed ~= nil);
		ok(frep.clean);
	end);

	test("alternatives keep empty positions", function()
		local b = fresh();
		b = chain(b, {
			function(x) return BM.SetSlot(x, 1, "rings", 1, "accuria", cat); end,
			function(x) return BM.SetSlot(x, 1, "rings", 3, "quick_strike", cat); end,
			function(x) return BM.SetSlot(x, 1, "trinkets", 2, "earthstrike", cat); end,
			function(x) return BM.SetSlot(x, 1, "trinkets", 4, "hoj", cat); end,
			function(x) return BM.SetSlot(x, 1, "amulets", 3, "warglaives", cat); end,
		});
		eq(b.phases[1].rings, { "accuria", "", "quick_strike", "" });
		eq(b.phases[1].trinkets, { "", "earthstrike", "", "hoj" });
		eq(b.phases[1].amulets, { "", "", "warglaives", "" });
		b = BM.ClearSlot(b, 1, "rings", 1, cat);
		eq(b.phases[1].rings, { "", "", "quick_strike", "" });
		local s = BM.Slots(b.phases[1], "rings");
		eq(#s, 1);
		eq(s[1].pos, 3);
		eq(s[1].role, "alt");
		eq(BM.Slots(b.phases[1], "trinkets")[1].role, "main");
		b = BM.SwapSlots(b, 1, "trinkets", 2, 4, cat);
		eq(b.phases[1].trinkets, { "", "hoj", "", "earthstrike" });
		local bad, rep = BM.SetSlot(b, 1, "rings", 5, "accuria", cat);
		eq(bad, nil);
		issue(rep, "INVALID_VALUE");
		local dup, rep2 = BM.SetSlot(b, 1, "rings", 1, "quick_strike", cat);
		eq(dup, nil);
		issue(rep2, "DUPLICATE_PIECE");
		local wrong, rep3 = BM.SetSlot(b, 1, "rings", 1, "earthstrike", cat);
		eq(wrong, nil);
		issue(rep3, "WRONG_SLOT");
	end);

	test("a worn piece satisfies at most one position", function()
		local ph = BM.NewPhase("");
		ph.rings = { "accuria", "", "accuria", "quick_strike" };            -- duplicate planned (imported)
		local r = BM.AssignOwned(ph, "rings", { "accuria", "dark_iron" });
		eq(r.matched, { [1] = "accuria" });
		eq(r.missing, { [3] = "accuria", [4] = "quick_strike" });
		eq(r.extra, { "dark_iron" });
		local both = BM.AssignOwned(ph, "rings", { "accuria", "accuria" });
		eq(both.matched, { [1] = "accuria", [3] = "accuria" }, "two physical pieces may fill two positions");
		local raw = U.DeepCopy(fresh());
		raw.phases[1].rings = { "accuria", "", "accuria", "" };
		local _, rep = BM.Normalize(raw, cat);
		issue(rep, "DUPLICATE_PIECE");
	end);

	test("four phases, empty phases are kept", function()
		local b = fresh();
		b = BM.SetNotes(b, 4, "late game", cat);
		b = BM.SetLabel(b, 1, "Début", cat);
		eq(#b.phases, 4);
		eq(b.phases[2].spells, {});
		eq(b.phases[3].notes, "");
		eq(b.phases[4].notes, "late game");
		local raw = { id = "r", name = "few", class = "warrior", revision = 1, catalog = "", phases = { { spells = { "whirlwind" } } } };
		local n, rep = BM.Normalize(raw, cat);
		eq(#n.phases, 4);
		issue(rep, "PARTIAL");
		eq(n.phases[1].spells[1], { key = "whirlwind", mode = "acquire" });
		raw.phases = { {}, {}, {}, {}, { notes = "fifth" }, { notes = "sixth" } };
		n, rep = BM.Normalize(raw, cat);
		eq(#n.phases, 4);
		eq(#n.ext.extraPhases, 2);
		eq(n.ext.extraPhases[1].notes, "fifth");
		issue(rep, "OVERFLOW_PRESERVED");
	end);

	test("unknown keys are preserved with a warning", function()
		local raw = fresh();
		raw = U.DeepCopy(raw);
		raw.phases[1].spells = { { key = "mystery_spell", mode = "acquire" }, { key = "whirlwind", mode = "acquire" } };
		raw.phases[1].rings = { "mystery_ring", "", "", "" };
		raw.phases[1].banish = { "mystery_banish" };
		local b, rep = BM.Normalize(raw, cat);
		ok(b ~= nil);
		ok(rep.clean, "unknown keys are warnings, not conflicts");
		eq(#rep.warnings, 3);
		issue(rep, "UNKNOWN_KEY", "phases[1].spells[1]");
		eq(b.phases[1].spells[1].key, "mystery_spell");
		eq(b.phases[1].rings[1], "mystery_ring");
		eq(b.phases[1].banish, { "mystery_banish" });
		local added, arep = BM.AddSpell(fresh(), 1, "future_spell", nil, cat);
		ok(added ~= nil);
		issue(arep, "UNKNOWN_KEY");
	end);

	test("other-class spells and wrong slots are conflicts kept as data", function()
		local raw = U.DeepCopy(fresh());
		raw.phases[1].spells = { { key = "death_coil", mode = "acquire" } };
		raw.phases[1].trinkets = { "accuria", "", "", "" };
		local b, rep = BM.Normalize(raw, cat);
		ok(b ~= nil);
		issue(rep, "WRONG_CLASS");
		issue(rep, "WRONG_SLOT");
		eq(b.phases[1].spells[1].key, "death_coil");
		local moved, mrep = BM.SetClass(BM.AddSpell(fresh(), 1, "whirlwind", nil, cat), "mage", cat);
		eq(moved, nil, "changing class must not silently create conflicts");
		issue(mrep, "WRONG_CLASS");
	end);

	test("stable reordering", function()
		local b = fresh();
		local steps = {};
		for _, k in ipairs({ "whirlwind", "execute", "cleave", "rend" }) do steps[#steps + 1] = function(x) return BM.AddSpell(x, 1, k, nil, cat); end; end
		b = chain(b, steps);
		local function keys(x) local o = {}; for i, g in ipairs(x.phases[1].spells) do o[i] = g.key; end return o; end
		eq(keys(b), { "whirlwind", "execute", "cleave", "rend" });
		local m = BM.MoveSpell(b, 1, 2, 4, cat);
		eq(keys(m), { "whirlwind", "cleave", "rend", "execute" });
		eq(keys(BM.MoveSpell(m, 1, 4, 2, cat)), { "whirlwind", "execute", "cleave", "rend" });
		eq(keys(BM.MoveSpell(b, 1, 3, 3, cat)), keys(b));
		local x, rep = BM.MoveSpell(b, 1, 1, 9, cat);
		eq(x, nil);
		eq(keys(b), { "whirlwind", "execute", "cleave", "rend" });
		eq(keys(BM.RemoveSpell(b, 1, "execute", cat)), { "whirlwind", "cleave", "rend" });
		local ins = BM.AddSpell(b, 1, "bloodthirst", { index = 1 }, cat);
		eq(keys(ins), { "bloodthirst", "whirlwind", "execute", "cleave", "rend" });
		local bb = BM.AddBanish(BM.AddBanish(fresh(), 1, "rend", cat), 1, "bloodrage", cat);
		eq(BM.MoveBanish(bb, 1, 1, 2, cat).phases[1].banish, { "bloodrage", "rend" });
	end);

	test("rank targets, unlimited improvement, acquisition", function()
		local b = BM.AddSpell(fresh(), 1, "whirlwind", { mode = "rank", rank = 3 }, cat);
		eq(b.phases[1].spells[1], { key = "whirlwind", mode = "rank", rank = 3 });
		eq((BM.AddSpell(fresh(), 1, "execute", { mode = "rank" }, cat)), nil, "rank mode needs a rank");
		eq((BM.AddSpell(fresh(), 1, "execute", { mode = "rank", rank = 0 }, cat)), nil);
		eq((BM.AddSpell(fresh(), 1, "execute", { mode = "rank", rank = 1.5 }, cat)), nil);
		eq((BM.AddSpell(fresh(), 1, "execute", { mode = "acquire", rank = 2 }, cat)), nil, "rank only with mode rank");
		eq((BM.AddSpell(fresh(), 1, "execute", { mode = "bogus" }, cat)), nil);
		local u = BM.SetSpellTarget(b, 1, "whirlwind", "unlimited", nil, cat);
		eq(u.phases[1].spells[1], { key = "whirlwind", mode = "unlimited" });
		ok(not BM.CountsForCompletion(u.phases[1].spells[1]));
		ok(BM.CountsForCompletion(b.phases[1].spells[1]));
		local a = BM.SetSpellTarget(u, 1, "whirlwind", "acquire", nil, cat);
		eq(a.phases[1].spells[1].mode, "acquire");
	end);

	test("goal statuses UNKNOWN / BLOCKED / ACHIEVED / PENDING stay distinct", function()
		local S = BM.STATUS;
		local acq, rank, unl = { key = "a", mode = "acquire" }, { key = "a", mode = "rank", rank = 3 }, { key = "a", mode = "unlimited" };
		eq((BM.EvaluateGoal(acq, nil)), S.UNKNOWN);
		eq((BM.EvaluateGoal(acq, { known = false, spells = { a = 1 } })), S.UNKNOWN, "unknown data never reads as achieved");
		eq((BM.EvaluateGoal(acq, { known = true, spells = {} })), S.PENDING);
		eq((BM.EvaluateGoal(acq, { known = true, spells = { a = 1 } })), S.ACHIEVED);
		eq((BM.EvaluateGoal(acq, { known = true, spells = {}, blocked = { a = "all slots full" } })), S.BLOCKED);
		eq((BM.EvaluateGoal(acq, { known = true, spells = { a = 1 }, blocked = { a = "x" } })), S.ACHIEVED, "owned beats blocked");
		eq((BM.EvaluateGoal(rank, { known = true, spells = { a = 2 } })), S.PENDING);
		eq((BM.EvaluateGoal(rank, { known = true, spells = { a = 3 } })), S.ACHIEVED);
		eq((BM.EvaluateGoal(rank, { known = true, spells = { a = true } })), S.UNKNOWN, "owned with unknown rank");
		eq((BM.EvaluateGoal(rank, { known = true, spells = {} })), S.PENDING);
		eq((BM.EvaluateGoal(unl, { known = true, spells = { a = 9 } })), S.PENDING, "unlimited is never achieved");
		eq((BM.EvaluateGoal(unl, { known = true, spells = {}, blocked = { a = "r" } })), S.BLOCKED);
		local seen = {};
		for _, v in pairs(S) do seen[v] = true; end
		eq(U.Len(seen), 4);
	end);

	test("talents, stats, notes and links are kept and round-trip", function()
		local b = fresh();
		b = chain(b, {
			function(x) return BM.SetTalents(x, "10203-000-0110", cat); end,
			function(x) return BM.SetStat(x, 1, "damage", 50, cat); end,
			function(x) return BM.SetStat(x, 1, "crit", 12.5, cat); end,
			function(x) return BM.SetNotes(x, 1, "Ligne 1\nLigne 2 \195\169 \226\154\148", cat); end,
			function(x) return BM.SetLink(x, 1, "https://azreborn.com/planner/warrior", cat); end,
		});
		eq(b.talents, "10203-000-0110");
		eq(b.phases[1].stats, { damage = 50, crit = 12.5 });
		eq(b.phases[1].notes, "Ligne 1\nLigne 2 \195\169 \226\154\148");
		eq(b.phases[1].link, "https://azreborn.com/planner/warrior");
		local back = H.roundtrip(b);
		ok(H.deepeq(back, b), "serialised build differs");
		local n = BM.Normalize(back, cat);
		ok(H.deepeq(n, b), "normalise is not idempotent");
		b = BM.SetStat(b, 1, "damage", 0, cat);
		eq(b.phases[1].stats.damage, 0);
	end);

	test("extensions and unknown fields are preserved through normalisation", function()
		local raw = U.DeepCopy(fresh());
		raw.futureField = { a = 1, b = { 2, 3 } };
		raw.ext = { site = { v = 1 } };
		raw.phases[2].mood = "angry";
		raw.phases[2].ext = { x = true };
		local b, rep = BM.Normalize(raw, cat);
		ok(b ~= nil);
		eq(b.ext.site, { v = 1 });
		eq(b.ext.futureField, { a = 1, b = { 2, 3 } });
		eq(b.phases[2].ext, { x = true, mood = "angry" });
		eq(raw.futureField.a, 1, "raw input untouched");
		local again = BM.Normalize(b, cat);
		ok(H.deepeq(again, b), "second normalisation changed the build");
		local edited = BM.SetName(b, "n", cat);
		eq(edited.ext.futureField, { a = 1, b = { 2, 3 } });
	end);

	test("limits and invalid values are errors and nothing mutates", function()
		local raw = U.DeepCopy(fresh());
		local snapshot = U.DeepCopy(raw);
		local function bad(mutate, code, path, nocopy)
			local r = U.DeepCopy(raw);
			mutate(r);
			local before = (not nocopy) and U.DeepCopy(r) or nil;
			local b, rep = BM.Normalize(r, cat);
			eq(b, nil);
			issue(rep, code, path);
			if before then ok(H.deepeq(r, before), "Normalize mutated its input"); end
		end
		bad(function(r) r.name = string.rep("x", 241); end, "TOO_LONG", "name");
		bad(function(r) r.phases[1].notes = string.rep("n", 8001); end, "TOO_LONG", "phases[1].notes");
		bad(function(r) r.phases[1].link = string.rep("l", 901); end, "TOO_LONG", "phases[1].link");
		bad(function(r) r.phases[1].label = string.rep("l", 97); end, "TOO_LONG", "phases[1].label");
		bad(function(r) r.talents = string.rep("1", 401); end, "TOO_LONG", "talents");
		bad(function(r) r.phases[1].stats = { damage = 1000 }; end, "INVALID_VALUE", "phases[1].stats.damage");
		bad(function(r) r.phases[1].stats = { damage = 0 / 0 }; end, "INVALID_VALUE", "phases[1].stats.damage", true);
		bad(function(r) r.phases[1].stats = { damage = -1 }; end, "INVALID_VALUE", "phases[1].stats.damage");
		bad(function(r) r.phases[1].stats = { damage = "5" }; end, "INVALID_VALUE", "phases[1].stats.damage");
		bad(function(r) r.phases[1].spells = { { key = "a", mode = "acquire" }, { key = "b", mode = "acquire" }, { key = "c", mode = "acquire" },
			{ key = "d", mode = "acquire" }, { key = "e", mode = "acquire" }, { key = "f", mode = "acquire" }, { key = "g", mode = "acquire" } }; end, "TOO_MANY", "phases[1].spells");
		bad(function(r) r.phases[1].banish = { "a", "b", "c", "d" }; end, "TOO_MANY", "phases[1].banish");
		bad(function(r) r.revision = 0; end, "INVALID_VALUE", "revision");
		bad(function(r) r.revision = 1.5; end, "INVALID_VALUE", "revision");
		bad(function(r) r.name = 5; end, "INVALID_VALUE", "name");
		bad(function(r) r.phases = "nope"; end, "INVALID_VALUE", "phases");
		bad(function(r) r.phases[1].spells = { { mode = "acquire" } }; end, "INVALID_VALUE", "phases[1].spells[1]");
		bad(function(r) r.phases[1].spells = { { key = "whirlwind", mode = "rank", rank = 100 } }; end, "INVALID_VALUE", "phases[1].spells[1].rank");
		bad(function(r) r.phases[1].rings = { 1, 2, 3, 4 }; end, "INVALID_VALUE", "phases[1].rings[1]");
		bad(function(r) r.ext = { f = function() end }; end, "EXT_REJECTED", "ext", true);
		bad(function(r) local d = {}; local c = d; for i = 1, 12 do c.n = {}; c = c.n; end r.ext = d; end, "EXT_REJECTED", "ext");
		bad(function(r) r.id = nil; end, "INVALID_VALUE", "id");
		ok(H.deepeq(raw, snapshot));
		local cyc = U.DeepCopy(raw);
		cyc.ext.self = cyc.ext;
		local b, rep = BM.Normalize(cyc, cat);
		eq(b, nil, "a cycle must be refused, not looped on");
		eq((BM.Normalize(nil, cat)), nil);
		eq((BM.Normalize("x", cat)), nil);
	end);

	test("a refused edit leaves the source untouched", function()
		local b = BM.AddSpell(fresh(), 1, "whirlwind", nil, cat);
		local before = U.DeepCopy(b);
		eq((BM.AddBanish(b, 1, "whirlwind", cat)), nil);
		eq((BM.SetStat(b, 1, "damage", 5000, cat)), nil);
		eq((BM.RemoveSpell(b, 1, "execute", cat)), nil);
		eq((BM.SetNotes(b, 9, "x", cat)), nil);
		eq((BM.SetName(b, string.rep("x", 300), cat)), nil);
		ok(H.deepeq(b, before));
		eq(b.revision, before.revision);
	end);

	test("unknown classes and other catalogue versions are warnings", function()
		local f, rep = BM.New({ id = "f", name = "future", class = "necromancer" }, cat);
		ok(f ~= nil);
		issue(rep, "UNKNOWN_CLASS");
		local fs = BM.AddSpell(f, 1, "raise_dead", nil, cat);
		ok(fs ~= nil, "no class check for an unknown class");
		local old = U.DeepCopy(fresh());
		old.catalog = "0000000000000000";
		local b, orep = BM.Normalize(old, cat);
		ok(b ~= nil);
		issue(orep, "CATALOG_DIFFERS");
		eq(b.catalog, "0000000000000000");
		local c = U.DeepCopy(fresh());
		c.class = "WARRIOR";
		eq(BM.Normalize(c, cat).class, "warrior", "token normalised to the canonical key");
		noissue(select(2, BM.Normalize(c, cat)), "UNKNOWN_CLASS");
	end);

	test("model code uses no catalogue name or icon as identifier", function()
		local src = H.readFile(H.root .. "/addon/RebornBuildPlanner/BuildModel.lua");
		no(src:find("%.icon") or src:find("%.head"), "BuildModel must not read icons or heads");
	end);
end
