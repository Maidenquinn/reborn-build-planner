-- Lot 1.1: lossless quarantine policy and transactional Open.
return function(H)
	local eq, ok, no, test = H.eq, H.ok, H.no, H.test;
	local ns = H.loadAddon();
	local cat = ns.Catalog.New(ns.GeneratedCatalog);
	local S, BM, U = ns.Storage, ns.BuildModel, ns.Util;
	local function now() return 1700000000; end
	local function mk(db) return S.Open(db, { catalog = cat, now = now }); end
	local function code(h) return h.issues[1] and h.issues[1].code; end

	local function dbWithJunk(n, preexisting)
		local db = S.NewDB();
		db.builds.good = BM.New({ id = "good", name = "good", class = "warrior" }, cat);
		db.library.warrior = { "good" };
		for i = 1, n do db.builds["junk" .. i] = "junk-" .. i; end
		for i = 1, preexisting or 0 do db.quarantine[i] = { reason = "OLD", raw = "old-" .. i, key = "o" .. i }; end
		return db;
	end
	local function rawsOf(h)
		local s = {};
		for _, q in ipairs(h:Quarantined()) do s[tostring(q.raw)] = true; end
		return s;
	end

	test("quarantine keeps 49 and 50 invalid records, all of them", function()
		for _, n in ipairs({ 49, 50 }) do
			local db = dbWithJunk(n);
			local snap = U.DeepCopy(db);
			local h = mk(db);
			eq(h.status, "OK", "n=" .. n);
			no(h.readOnly);
			eq(h:Counts().quarantine, n);
			eq(h:Counts().builds, 1);
			local raws = rawsOf(h);
			for i = 1, n do ok(raws["junk-" .. i], "junk-" .. i .. " kept"); end
			ok(H.deepeq(db, snap), "the loaded table was modified (n=" .. n .. ")");
		end
	end);

	test("51 and 100 invalid records: controlled refusal, read-only, nothing mutated, nothing dropped", function()
		for _, n in ipairs({ 51, 100 }) do
			local db = dbWithJunk(n);
			local snap = U.DeepCopy(db);
			local h = mk(db);
			eq(h.status, "REPAIR_REFUSED", "n=" .. n);
			ok(h.readOnly);
			ok(h.db == db, "the original table must be returned");
			ok(H.deepeq(db, snap), "original modified (n=" .. n .. ")");
			eq(code(h), "QUARANTINE_FULL");
			local msg = h.issues[1].message;
			ok(msg:find(tostring(n), 1, true) and msg:find("50", 1, true), "diagnostic names the counts: " .. msg);
			local id, err = h:Create({ name = "x", class = "warrior" });
			eq(err.code, "READ_ONLY");
			eq(h:Counts().builds, n + 1, "read access still works on the untouched original");
		end
	end);

	test("a saturated pre-existing quarantine is never truncated", function()
		local full = dbWithJunk(0, 50);
		local snap = U.DeepCopy(full);
		local h = mk(full);
		eq(h.status, "OK");
		eq(h:Counts().quarantine, 50);
		ok(H.deepeq(full, snap));
		ok(h.db == full, "nothing to repair: the loaded table is kept");
		local more = dbWithJunk(1, 50);
		local snap2 = U.DeepCopy(more);
		local h2 = mk(more);
		eq(h2.status, "REPAIR_REFUSED");
		eq(code(h2), "QUARANTINE_FULL");
		ok(H.deepeq(more, snap2));
		eq(#more.quarantine, 50);
		eq(more.quarantine[1].raw, "old-1");
		local h3 = mk(dbWithJunk(5, 45));
		eq(h3.status, "OK");
		eq(h3:Counts().quarantine, 50);
	end);

	test("migration obeys the same rule", function()
		local function proto(n)
			local d = { builds = { { name = "ok", class = "warrior" } } };
			for i = 1, n do d.builds[#d.builds + 1] = "bad" .. i; end
			return d;
		end
		local h = mk(proto(50));
		eq(h.status, "MIGRATED");
		eq(h:Counts().quarantine, 50);
		local src = proto(51);
		local snap = U.DeepCopy(src);
		local h2 = mk(src);
		eq(h2.status, "MIGRATION_FAILED");
		ok(h2.db == src and h2.readOnly);
		ok(H.deepeq(src, snap));
		ok(h2.issues[1].message:find("QUARANTINE_FULL", 1, true) or h2.issues[1].message:find("quarantine", 1, true), h2.issues[1].message);
	end);

	test("Open works on a copy: a repaired database never mutates the loaded table", function()
		local good = BM.New({ id = "g", name = "g", class = "warrior" }, cat);
		local partial = { id = "p", name = "p", class = "mage", phases = { { spells = { "frostbolt" } } } };
		local db = { schema = 1, counter = 3, builds = { g = good, p = partial, bad = { id = "bad", name = 7 }, other = "text" },
			library = { warrior = { "ghost", "g" } }, active = { warrior = "ghost", mage = "g" },
			trash = {}, futureTop = { keep = true }, ext = { a = 1 } };
		local snap = U.DeepCopy(db);
		local h = mk(db);
		eq(h.status, "OK");
		ok(H.deepeq(db, snap), "loaded table was mutated by Open");
		ok(h.db ~= db, "a repaired result is a new table");
		eq(h:Counts().builds, 2);
		eq(h:Counts().quarantine, 2);
		eq(h.db.active, {});
		eq(h.db.futureTop, { keep = true });
		eq(h.db.settings, {});
		eq(#h:Get("p").phases, 4);
		local again = mk(h.db);
		eq(again.status, "OK");
		ok(again.db == h.db, "an already-consistent table is kept as is");
		eq(#again.issues, 0);
	end);

	test("a clean database is opened without any change or copy", function()
		local h0 = mk(nil);
		h0:Create({ name = "x", class = "warrior" });
		local db = H.roundtrip(h0.db);
		local h = mk(db);
		ok(h.db == db);
		eq(h.status, "OK");
	end);

	test("source limits are checked before anything else", function()
		local huge = S.NewDB();
		local blob = {};
		for i = 1, S.LIMITS.dbNodes + 10 do blob[i] = i; end
		huge.ext.blob = blob;
		local h = mk(huge);
		eq(h.status, "REPAIR_REFUSED");
		eq(code(h), "SOURCE_REJECTED");
		ok(h.readOnly and h.db == huge);
		local withFn = S.NewDB();
		withFn.ext.f = function() end;
		h = mk(withFn);
		eq(code(h), "SOURCE_REJECTED");
		ok(h.db == withFn and type(withFn.ext.f) == "function");
		local cyc = S.NewDB();
		cyc.ext.self = cyc.ext;
		h = mk(cyc);
		eq(code(h), "SOURCE_REJECTED");
		local deep = S.NewDB();
		local c = deep.ext;
		for i = 1, S.LIMITS.dbDepth + 3 do c.n = {}; c = c.n; end
		h = mk(deep);
		eq(code(h), "SOURCE_REJECTED");
		ok(h.readOnly);
	end);

	test("invariants are verified on the repaired copy; a violation refuses the whole result", function()
		local db = dbWithJunk(2);
		local snap = U.DeepCopy(db);
		S._hooks.afterSettle = function(work) work.library.warrior = { "does-not-exist" }; end
		local h = mk(db);
		S._hooks.afterSettle = nil;
		eq(h.status, "REPAIR_REFUSED");
		eq(code(h), "INVARIANT");
		ok(h.readOnly and h.db == db);
		ok(H.deepeq(db, snap));
		S._hooks.afterSettle = function(work) work.builds.good.revision = "x"; end
		h = mk(dbWithJunk(1));
		S._hooks.afterSettle = nil;
		eq(code(h), "INVARIANT");
		eq(mk(dbWithJunk(1)).status, "OK");
	end);

	test("trash overflow is reported, not silent", function()
		local h = mk(nil);
		local last;
		for i = 1, S.LIMITS.trash + 1 do
			local id = h:Create({ name = "t" .. i, class = "warrior" });
			local r, evicted = h:Delete(id);
			ok(r);
			last = evicted;
		end
		eq(last and last.name, "t1", "the build dropped by the cap is named in the return value");
		eq(#h:Trash(), S.LIMITS.trash);
	end);
end
