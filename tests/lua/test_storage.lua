return function(H)
	local eq, ok, no, test, issue = H.eq, H.ok, H.no, H.test, H.issue;
	local ns = H.loadAddon();
	local cat = ns.Catalog.New(ns.GeneratedCatalog);
	local S, BM, U = ns.Storage, ns.BuildModel, ns.Util;
	local function now() return 1700000000; end
	local function mk(db) return S.Open(db, { catalog = cat, now = now }); end
	local function code(err) return err and err.code; end

	local function proto()   -- schema 0: the internal prototype layout (see Storage.lua)
		return {
			builds = {
				{ name = "WW", class = "warrior", spells = { "whirlwind", "execute" }, banish = { "rend" }, notes = "n1", legacyFlag = 7 },
				{ name = "Mage", class = "MAGE", spells = {}, talents = "10-0-0" },
			},
			active = { warrior = 1 }, settings = { lang = "frFR", futureSetting = "keep" }, someOldThing = { 1, 2 },
		};
	end

	test("first initialisation", function()
		local h = mk(nil);
		eq(h.status, "CREATED");
		no(h.readOnly);
		eq(h.db.schema, 1);
		eq(h.db.addon, "RebornBuildPlanner");
		eq(h:Counts(), { builds = 0, trash = 0, quarantine = 0, backups = 0 });
		eq(h:List(), {});
		eq(h:GetActive("warrior"), nil);
		eq(h:GetSetting("lang"), "auto");
		eq(h:GetSetting("advancedPhases"), false);
	end);

	test("create, read, reload from a real serialised SavedVariables text", function()
		local h = mk(nil);
		local a = h:Create({ name = "WW", class = "warrior" });
		local b = h:Create({ name = "Arms", class = "warrior", talents = "5-0-0" });
		local c = h:Create({ name = "Fire", class = "mage" });
		ok(a and b and c and a ~= b and b ~= c);
		ok(h:SetActive("warrior", b));
		local g = h:Get(a);
		g = BM.AddSpell(g, 1, "whirlwind", nil, cat);
		ok(h:Update(a, g));
		local text = H.serialize("RebornBuildPlannerDB", h.db);
		local loaded = H.reload("RebornBuildPlannerDB", text);
		local h2 = mk(loaded);
		eq(h2.status, "OK");
		ok(H.deepeq(h2.db.builds, h.db.builds));
		eq(h2:GetActive("warrior"), b);
		eq(h2:Get(a).phases[1].spells[1].key, "whirlwind");
		eq(h2:Get(a).revision, 2);
		eq(#h2:List("warrior"), 2);
		eq(#h2:List("mage"), 1);
		eq(#h2:List(), 3);
		-- the next id after a reload continues the counter, never reuses one
		local d = h2:Create({ name = "new", class = "rogue" });
		no(d == a or d == b or d == c);
	end);

	test("several builds per class, one active build per class", function()
		local h = mk(nil);
		local w1, w2 = h:Create({ name = "w1", class = "warrior" }), h:Create({ name = "w2", class = "warrior" });
		local m1 = h:Create({ name = "m1", class = "mage" });
		ok(h:SetActive("warrior", w1));
		ok(h:SetActive("mage", m1));
		ok(h:SetActive("warrior", w2));
		eq(h:GetActive("warrior"), w2);
		eq(h:GetActive("mage"), m1);
		local r, err = h:SetActive("warrior", m1);
		eq(r, nil);
		eq(code(err), "NOT_FOUND");
		eq(h:GetActive("warrior"), w2);
		ok(h:ClearActive("warrior"));
		eq(h:GetActive("warrior"), nil);
		eq(h:GetActive("mage"), m1);
		local names = {};
		for i, e in ipairs(h:List("warrior")) do names[i] = e.name; end
		eq(names, { "w1", "w2" });
	end);

	test("update: revision rule, id rule, invalid refusal, class move", function()
		local h = mk(nil);
		local id = h:Create({ name = "x", class = "warrior" });
		ok(h:SetActive("warrior", id));
		local g = h:Get(id);
		local e = BM.SetName(g, "edited", cat);
		ok(h:Update(id, e));
		eq(h:Get(id).name, "edited");
		local r, err = h:Update(id, e);
		eq(code(err), "STALE_REVISION");
		r, err = h:Update(id, g);                             -- an older editor copy
		eq(code(err), "STALE_REVISION");
		eq(h:Get(id).name, "edited");
		local other = BM.Clone(e);
		other.id = "zzz"; other.revision = 9;
		r, err = h:Update(id, other);
		eq(code(err), "ID_MISMATCH");
		local broken = BM.Clone(e);
		broken.revision = 10;
		broken.phases[1].notes = string.rep("x", 9000);
		local snap = U.DeepCopy(h.db);
		r, err = h:Update(id, broken);
		eq(code(err), "INVALID_BUILD");
		ok(H.deepeq(snap, h.db), "refused update changed the database");
		r, err = h:Update("nope", e);
		eq(code(err), "NOT_FOUND");
		local moved = BM.SetClass(BM.Clone(h:Get(id)), "mage", cat);
		ok(moved ~= nil);
		ok(h:Update(id, moved));
		eq(#h:List("warrior"), 0);
		eq(#h:List("mage"), 1);
		eq(h:GetActive("warrior"), nil, "active pointer must not survive a class change");
		-- Get returns copies: editing them never touches storage
		local copy = h:Get(id);
		copy.name = "hacked";
		eq(h:Get(id).name, "edited");
	end);

	test("duplicate, delete (trash), restore", function()
		local h = mk(nil);
		local id = h:Create({ name = "Orig", class = "warrior" });
		ok(h:SetActive("warrior", id));
		local g = BM.AddSpell(h:Get(id), 1, "whirlwind", nil, cat);
		ok(h:Update(id, g));
		local d = h:Duplicate(id);
		ok(d and d ~= id);
		eq(h:Get(d).name, "Orig (copy)");
		eq(h:Get(d).revision, 1);
		eq(h:Get(d).phases[1].spells[1].key, "whirlwind");
		ok(h:Update(d, BM.SetName(h:Get(d), "changed", cat)));
		eq(h:Get(id).name, "Orig", "duplicate shares nothing with its source");
		ns.Locale.SetLang("frFR");
		eq(h:Get(h:Duplicate(id)).name, "Orig (copie)");
		ns.Locale.SetLang("enUS");
		local long = h:Create({ name = string.rep("\195\169", 120), class = "warrior" });     -- 240 bytes
		local dl = h:Get(h:Duplicate(long));
		ok(#dl.name <= 240 and (#dl.name - 7) % 2 == 0 and dl.name:sub(-7) == " (copy)", "UTF-8 safe cut");
		ok(h:Delete(id));
		eq(h:Get(id), nil);
		eq(h:GetActive("warrior"), nil);
		eq(#h:Trash(), 1);
		eq(h:Trash()[1].id, id);
		ok(h:Restore(id));
		eq(h:Get(id).name, "Orig");
		eq(h:GetActive("warrior"), id, "active status comes back with the build");
		eq(#h:Trash(), 0);
		local r, err = h:Delete("none");
		eq(code(err), "NOT_FOUND");
		r, err = h:Restore("none");
		eq(code(err), "NOT_FOUND");
	end);

	test("trash is capped; only its overflow is ever dropped for good", function()
		local h = mk(nil);
		for i = 1, 25 do
			local id = h:Create({ name = "b" .. i, class = "warrior" });
			ok(h:Delete(id));
		end
		eq(#h:Trash(), S.LIMITS.trash);
		eq(h:Trash()[1].name, "b6");
	end);

	test("library limit is enforced and documented", function()
		local h = mk(nil);
		eq(S.LIMITS.builds, 200);
		for i = 1, 200 do
			ok(h:Create({ name = "b" .. i, class = "warrior" }), "create " .. i);
		end
		local id, err = h:Create({ name = "201", class = "warrior" });
		eq(id, nil);
		eq(code(err), "LIBRARY_FULL");
		id, err = h:Duplicate(h:List()[1].id);
		eq(code(err), "LIBRARY_FULL");
		id, err = h:ImportBuilds({ { name = "x", class = "warrior", phases = {} } });
		eq(code(err), "LIBRARY_FULL");
		eq(h:Counts().builds, 200);
		local text = H.serialize("RebornBuildPlannerDB", h.db);
		ok(#text < 1000000, "200 empty builds serialise to " .. #text .. " bytes (indented test serialiser)");
		local back = mk(H.reload("RebornBuildPlannerDB", text));
		eq(back.status, "OK");
		eq(back:Counts().builds, 200);
	end);

	test("import is all-or-nothing and never overwrites", function()
		local h = mk(nil);
		local keep = h:Create({ name = "keep", class = "warrior" });
		local before = U.DeepCopy(h.db);
		local good = { id = keep, name = "imported", class = "warrior", revision = 3, catalog = "", phases = { { spells = { "whirlwind" } } }, extra = 1 };
		local bad = { name = "bad", class = "warrior", phases = { { notes = string.rep("n", 9000) } } };
		local ids, err = h:ImportBuilds({ good, bad, good });
		eq(ids, nil);
		eq(code(err), "INVALID_IMPORT");
		eq(err.detail[1].index, 2);
		ok(H.deepeq(before, h.db), "failed import changed the database");
		ids, err = h:ImportBuilds({ good, good });
		eq(#ids, 2);
		ok(ids[1] ~= keep and ids[2] ~= keep and ids[1] ~= ids[2], "ids are new");
		eq(h:Get(keep).name, "keep");
		eq(h:Get(ids[1]).name, "imported");
		eq(h:Get(ids[1]).ext.extra, 1, "unknown field kept");
		eq(h:Get(ids[1]).revision, 3);
		ids, err = h:ImportBuilds("not a list");
		eq(code(err), "INVALID_IMPORT");
		local id, e2 = h:Add({ name = "x" });
		eq(id, nil);
		eq(code(e2), "INVALID_BUILD");
	end);

	test("settings are independent and validated; unknown settings survive", function()
		local h = mk(nil);
		ok(h:SetSetting("lang", "frFR"));
		eq(h:GetSetting("lang"), "frFR");
		local r, err = h:SetSetting("lang", "klingon");
		eq(code(err), "INVALID_VALUE");
		r, err = h:SetSetting("nope", 1);
		eq(code(err), "UNKNOWN_SETTING");
		eq(h:GetSetting("lang"), "frFR");
		h.db.settings.futureSetting = { a = 1 };
		local h2 = mk(H.roundtrip(h.db));
		eq(h2.db.settings.futureSetting, { a = 1 });
		eq(h2:GetSetting("lang"), "frFR");
		eq(h2.db.builds, {}, "settings never touch builds");
	end);

	test("migration from schema 0 succeeds on a copy and keeps a backup", function()
		local original = proto();
		local snapshot = U.DeepCopy(original);
		local h = mk(original);
		eq(h.status, "MIGRATED");
		no(h.readOnly);
		ok(H.deepeq(original, snapshot), "the original table was modified");
		ok(h.db ~= original, "migration must produce a new table");
		eq(h.db.schema, 1);
		eq(h:Counts().builds, 2);
		local w = h:List("warrior")[1];
		eq(w.name, "WW");
		local g = h:Get(w.id);
		eq(g.phases[1].spells[1], { key = "whirlwind", mode = "acquire" });
		eq(g.phases[1].spells[2].key, "execute");
		eq(g.phases[1].banish, { "rend" });
		eq(g.phases[1].notes, "n1");
		eq(g.ext.legacyFlag, 7, "unknown prototype field preserved");
		eq(g.revision, 1);
		eq(h:Get(h:List("mage")[1].id).talents, "10-0-0");
		eq(h:GetActive("warrior"), w.id);
		eq(h:GetSetting("lang"), "frFR");
		eq(h.db.settings.futureSetting, "keep");
		eq(h.db.ext.someOldThing, { 1, 2 });
		eq(#h.db.backups, 1);
		eq(h.db.backups[1].schema, 0);
		ok(H.deepeq(h.db.backups[1].data, snapshot), "backup differs from the original");
		-- the migrated table survives a reload and opens as current
		local again = mk(H.roundtrip(h.db));
		eq(again.status, "OK");
		eq(again:Counts().builds, 2);
		-- recovery path: the backup alone reproduces the same result
		local h3 = mk(U.DeepCopy(h.db.backups[1].data));
		eq(h3.status, "MIGRATED");
		ok(H.deepeq(h3.db.builds, h.db.builds));
		ok(h:DropBackups());
		eq(#h.db.backups, 0);
	end);

	test("migration with unreadable entries quarantines them, nothing is lost", function()
		local src = proto();
		src.builds[3] = "garbage";
		src.builds[4] = { name = "no class", spells = { "whirlwind" } };
		src.builds[5] = { name = "bad", class = "warrior", notes = string.rep("n", 9000) };
		local h = mk(src);
		eq(h.status, "MIGRATED");
		eq(h:Counts().builds, 2);
		eq(h:Counts().quarantine, 3);
		eq(h:Counts().builds + h:Counts().quarantine, 5);
		local raws = {};
		for _, q in ipairs(h:Quarantined()) do raws[#raws + 1] = q.raw; end
		ok(U.IndexOf(raws, "garbage"));
		eq(h.db.backups[1].data.builds[3], "garbage");
	end);

	test("interrupted or lossy migration: original untouched, storage read-only", function()
		local m = S._MIGRATIONS[0];
		local realStep = m.step;
		local original = proto();
		local snapshot = U.DeepCopy(original);
		m.step = function(src, ctx) local half = realStep(src, ctx); error("simulated crash mid-migration"); end
		local h = mk(original);
		m.step = realStep;
		eq(h.status, "MIGRATION_FAILED");
		ok(h.readOnly);
		ok(h.db == original, "the original table must stay the handle's table");
		ok(H.deepeq(original, snapshot));
		eq(code(h.issues[1]), "MIGRATION_FAILED");
		local id, err = h:Create({ name = "x", class = "warrior" });
		eq(code(err), "READ_ONLY");
		for _, f in ipairs({ "Add", "Update", "Delete", "Restore", "Duplicate", "SetActive", "ClearActive", "ImportBuilds", "SetSetting", "DropBackups" }) do
			local r, e = h[f](h, "a", "b");
			eq(code(e), "READ_ONLY", f);
		end
		-- a step that silently loses records is detected, not trusted
		m.step = function(src, ctx) local out = realStep(src, ctx); out.builds = {}; return out; end
		local h2 = mk(proto());
		m.step = realStep;
		eq(h2.status, "MIGRATION_FAILED");
		-- a table that cannot be copied (function inside) cannot be migrated and is left alone
		local weird = proto();
		weird.builds[1].oops = function() end;
		local h3 = mk(weird);
		eq(h3.status, "MIGRATION_FAILED");
		ok(h3.db == weird);
		-- and the working path is intact afterwards
		eq(mk(proto()).status, "MIGRATED");
	end);

	test("future schema is refused without touching the data", function()
		local fut = { schema = 99, builds = { x = { anything = true } }, brandNew = { 1 } };
		local snap = U.DeepCopy(fut);
		local h = mk(fut);
		eq(h.status, "FUTURE_SCHEMA");
		ok(h.readOnly);
		ok(h.db == fut);
		ok(H.deepeq(fut, snap));
		local id, err = h:Create({ name = "x", class = "warrior" });
		eq(code(err), "READ_ONLY");
		ok(H.deepeq(fut, snap));
		eq(h:GetSetting("lang"), "auto");
	end);

	test("not a database", function()
		for _, v in ipairs({ "text", 5, true }) do
			local h = mk(v);
			eq(h.status, "INVALID_DB");
			ok(h.readOnly);
			ok(h.db == v);
		end
		local h = mk({ schema = "one" });
		eq(h.status, "INVALID_DB");
	end);

	test("corrupted entries are quarantined, valid ones kept, unknown data preserved", function()
		local good = BM.New({ id = "g1", name = "good", class = "warrior" }, cat);
		local mism = BM.New({ id = "m1", name = "mismatch", class = "warrior" }, cat);
		good.ext.keepMe = { 1, 2, 3 };
		local db = {
			schema = 1, counter = 4, addon = "RebornBuildPlanner",
			builds = { g1 = good, junk = "text", bad = { id = "bad", name = 3 }, wrongkey = mism },
			library = { warrior = { "ghost", "g1", "g1" }, mage = "not a table" },
			active = { warrior = "ghost", mage = "g1", rogue = 5 },
			trash = { "junk", { build = { id = "t1", name = "t", class = "warrior", revision = 1 } }, {} },
			settings = "oops", futureTop = { 1 }, ext = { f = 1 },
		};
		local h = mk(db);
		eq(h.status, "OK");
		eq(h:Counts().builds, 1);
		eq(h:Get("g1").ext.keepMe, { 1, 2, 3 });
		eq(h.db.library, { warrior = { "g1" } });
		eq(h.db.active, {}, "dangling or mismatched active pointers are cleared");
		eq(h.db.settings, {});
		eq(h.db.futureTop, { 1 }, "unknown top-level data survives");
		eq(h.db.ext, { f = 1 });
		eq(#h.db.trash, 1);
		local reasons = {};
		for _, q in ipairs(h:Quarantined()) do reasons[#reasons + 1] = q.reason; end
		table.sort(reasons);
		eq(reasons, { "FIELD_NOT_A_TABLE:settings", "ID_MISMATCH", "INVALID_BUILD", "INVALID_BUILD", "INVALID_TRASH", "INVALID_TRASH" });
		local raw = {};
		for _, q in ipairs(h:Quarantined()) do if q.reason == "INVALID_BUILD" then raw[#raw + 1] = q.raw; end end
		ok(U.IndexOf(raw, "text"));
		eq(#h.issues >= 2, true);
		-- opening twice changes nothing more
		local before = U.DeepCopy(h.db);
		local h2 = mk(h.db);
		ok(H.deepeq(before, h2.db));
	end);

	test("an over-capacity quarantine is refused, never truncated (policy of Lot 1.1)", function()
		local db = S.NewDB();
		for i = 1, 70 do db.builds["junk" .. i] = "x" .. i; end
		local h = mk(db);
		eq(h.status, "REPAIR_REFUSED");
		ok(h.readOnly and h.db == db);
		eq(U.Len(db.builds), 70, "all 70 original records still there");
	end);
	test("builds missing optional fields are completed, not discarded", function()
		local db = S.NewDB();
		db.builds.p1 = { id = "p1", name = "partial", class = "warrior", phases = { { spells = { "whirlwind" } } } };
		local h = mk(db);
		eq(h:Counts().builds, 1);
		eq(#h:Get("p1").phases, 4);
		eq(h:Get("p1").revision, 1);
		eq(h:Get("p1").phases[1].spells[1].key, "whirlwind");
		eq(h.db.library, { warrior = { "p1" } });
	end);

	test("everything stored is plain serialisable data", function()
		local h = mk(proto());
		local id = h:Create({ name = "x", class = "warrior" });
		h:Delete(id);
		local text = H.serialize("RebornBuildPlannerDB", h.db);
		ok(not text:find("function"));
		ok(H.deepeq(H.reload("RebornBuildPlannerDB", text), h.db));
		local ok2 = U.Measure(h.db, S.LIMITS.dbNodes, S.LIMITS.dbDepth);
		ok(ok2);
	end);

	test("Lot 3 settings: window position, scale and last class are validated, persisted and reversible", function()
		local h = mk(nil);
		eq(h:GetSetting("scale"), 1);
		eq(h:GetSetting("lastClass"), "");
		eq(h:GetSetting("window"), nil);
		ok(h:SetSetting("window", { point = "TOPLEFT", x = -120.5, y = 40 }));
		ok(h:SetSetting("scale", 0.8));
		ok(h:SetSetting("lastClass", "mage"));
		local h2 = mk(H.roundtrip(h.db));
		eq(h2:GetSetting("window"), { point = "TOPLEFT", x = -120.5, y = 40 });
		eq(h2:GetSetting("scale"), 0.8);
		for _, bad in ipairs({ { "scale", 0.1 }, { "scale", 9 }, { "scale", "1" }, { "scale", 0 / 0 }, { "lastClass", 5 }, { "lastClass", string.rep("x", 65) },
			{ "window", "x" }, { "window", { point = "CENTER", x = 1 } }, { "window", { point = 5, x = 1, y = 1 } }, { "window", { point = "CENTER", x = 1e9, y = 0 } },
			{ "window", { point = "CENTER", x = 0 / 0, y = 0 } } }) do
			local r, err = h:SetSetting(bad[1], bad[2]);
			eq(r, nil, bad[1]);
			eq(err.code, "INVALID_VALUE");
		end
		eq(h:GetSetting("scale"), 0.8, "refused values change nothing");
		h.db.settings.window = nil;
		eq(h:GetSetting("window"), nil, "removing the saved position restores the default");
	end);
end
