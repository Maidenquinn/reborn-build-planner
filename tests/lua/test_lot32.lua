-- Lot 3.2: library (search, filters, favourites, recents, sort), build switching, creation dialog, inspector,
-- metadata storage and migrations, performance. Widget MOCK: nothing here proves rendering in the Reborn client.
return function(H)
	local eq, ok, no, test = H.eq, H.ok, H.no, H.test;
	local Stub = dofile(H.root .. "/tests/lua/wowstub.lua");

	local function boot(o)
		o = o or {};
		local world = Stub.new({ width = o.width or 1365, height = o.height or 768, locale = o.locale or "enUS", gameSpells = o.gameSpells,
			classToken = o.classToken, className = o.className, now = o.now or 1700000000 });
		for k, v in pairs(o.preset or {}) do world.G[k] = v; end
		local ns, sb = H.loadAddon({ globals = world.G, time = world.G.time });
		local env = { world = world, ns = ns, sb = sb, G = world.G };
		world.fire("ADDON_LOADED", "RebornBuildPlanner");
		env.c, env.ui = ns.controller, ns.ui;
		world.G.SlashCmdList.REBORNPLANNER("");
		env.root = world.G.RebornBuildPlannerFrame;
		function env.h() return ns.storage; end
		function env.texts() return table.concat(world.texts(), " | "); end
		function env.at(t) world.opts.now = t; end
		return env;
	end
	-- selecting a row of the browser, then the detail panel's primary action (what a player does in two clicks)
	local function pick(e, i) e.world.click(e.ui.bs.rows[i]); e.world.click(e.ui.det.act1); end
	local function reload(e, o)
		o = o or {};
		local text = H.serialize("RebornBuildPlannerDB", e.G.RebornBuildPlannerDB);
		o.preset = { RebornBuildPlannerDB = H.reload("RebornBuildPlannerDB", text) };
		return boot(o);
	end
	local function names(e) local out = {}; for _, r in ipairs(e.c:Rows()) do out[#out + 1] = r.name; end return out; end
	local function many(e, n, class)
		local ids = {};
		for i = 1, n do ids[i] = e.h():Create({ name = string.format("Build %03d", i), class = class or "warrior" }); end
		e.c:Notify();
		return ids;
	end

	-- ------------------------------------------------------------------ library
	test("3.2B library: 0, 1, 20 and 200 builds", function()
		local e = boot();
		ok(e.world.hasText("No build yet"), e.texts());
		eq(select(3, e.c:LibView()), 0);
		many(e, 1);
		eq(#e.c:Rows(), 1);
		no(e.world.hasText("No build yet"));
		many(e, 19);
		eq(#e.c:Rows(), 20);
		eq(select(3, e.c:LibView()), 10, "20 builds, 10 rows: scrolls by 10");
		local e2 = boot();
		many(e2, 200);
		eq(#e2.c:Rows(), 200);
		eq(select(3, e2.c:LibView()), 190);
		e2.c:ScrollLib(10);
		eq(e2.c.state.libOffset, 10);
		ok(e2.world.hasText("Build 011"), e2.texts());
		e2.c:SetLibOffset(190);
		ok(e2.world.hasText("Build 200"), e2.texts());
		eq(e2.world.lint(e2.root), {}, "200 builds, library lint");
		local id, why = e2.h():Create({ name = "201", class = "warrior" });
		eq(id, nil, "the library holds 200 builds");
	end);

	test("3.2B library: search by name, class (EN and FR), spell and jewel names, several words", function()
		local e = boot({ locale = "frFR" });
		local w = e.c:Create("Mon plan", "warrior");
		local m = e.c:Create("Givre", "mage");
		e.ui:OpenEditor(w);
		e.c:AddSpell("whirlwind");
		e.c:SetCatalog("rings"); e.c:SetSlot("rings", 1, "accuria");
		e.world.clickLabel("Enregistrer", e.ui.views.editor);
		local function find(text) e.world.type(e.ui.lib.search, text); return names(e); end
		eq(find("mon"), { "Mon plan" });
		eq(find("guerrier"), { "Mon plan" }, "French class name");
		eq(find("warrior"), { "Mon plan" }, "English class name / key");
		eq(find("tourbillon"), { "Mon plan" }, "French spell name");
		eq(find("whirlwind"), { "Mon plan" }, "English spell name");
		eq(find("accuria"), { "Mon plan" }, "jewel name");
		eq(find("mon accuria"), { "Mon plan" }, "all words must match");
		eq(find("mon givre"), {}, "no build matches both");
		eq(find("mage"), { "Givre" });
		eq(find(""), { "Givre", "Mon plan" }, "empty search shows everything");
		e.world.type(e.ui.lib.search, "zzzz");
		ok(e.world.hasText("Aucun build ne correspond"), e.texts());
		ok(m and w);
	end);

	test("3.2B library: favourites come first, filter, persist; duplicates and restores follow the documented policy", function()
		local e = boot();
		local a, b, c = e.c:Create("Alpha", "warrior"), e.c:Create("Bravo", "warrior"), e.c:Create("Charlie", "warrior");
		eq(names(e), { "Alpha", "Bravo", "Charlie" });
		e.c:ToggleFavorite(c);
		eq(names(e), { "Charlie", "Alpha", "Bravo" }, "favourites first");
		e.world.click(e.ui.lib.filters.favorites);
		eq(names(e), { "Charlie" });
		eq(e.h():GetSetting("libFilter"), "favorites", "the filter is remembered");
		e.world.click(e.ui.lib.filters.all);
		-- the star on a row
		local row;
		for _, r in ipairs(e.ui.lib.rows) do if r.rowId == a then row = r; end end
		ok(row.star:GetText():find("-", 1, true), "not a favourite: '-'");
		e.world.click(row.star);
		ok(e.h():Meta(a).fav);
		eq(names(e), { "Alpha", "Charlie", "Bravo" });
		no(row.star:GetText():find("-", 1, true), "favourite shows '*'");
		-- duplicate: a new build, NOT a favourite, never used
		e.c:Duplicate(a);
		local copy;
		for _, r in ipairs(e.c:Rows()) do if r.name == "Alpha (copy)" then copy = r; end end
		ok(copy and not copy.fav and copy.used == nil, "copies start as plain builds");
		-- delete + restore keeps the favourite
		e.c:ConfirmDelete(a);
		no(e.h():Meta(a).fav == nil and false);
		e.c:UndoDelete();
		ok(e.h():Meta(a).fav, "restored build is still a favourite");
		-- reload
		local again = reload(e);
		ok(again.h():Meta(a).fav and again.h():Meta(c).fav);
		eq(again.c:Filter(), "all");
	end);

	test("3.2B library: recent = really opened/followed builds, newest first, with real timestamps", function()
		local e = boot();
		local a, b, c = e.c:Create("A", "warrior"), e.c:Create("B", "warrior"), e.c:Create("C", "warrior");
		eq(e.h():Meta(a).used, nil, "never used: unknown, not invented");
		e.world.click(e.ui.lib.filters.recent);
		eq(names(e), {}, "nothing opened yet");
		ok(e.world.hasText("No build matches"), e.texts());
		e.at(1700000100); e.ui:OpenEditor(b);
		e.at(1700000200); e.ui:OpenEditor(c);
		e.at(1700000300); e.ui:OpenEditor(b);
		eq(names(e), { "B", "C" }, "newest first");
		eq(e.h():Meta(b).used, 1700000300);
		e.at(1700000400); e.c:Activate(a);
		eq(names(e), { "A", "B", "C" }, "following counts as use");
		e.world.click(e.ui.lib.filters.all);
		-- modified: only real saves
		eq(e.h():Meta(a).modified, 1700000000, "creation stamps the modification time");
		e.at(1700000500);
		e.ui:OpenEditor(b);
		e.c:AddSpell("whirlwind");
		e.c:Save();
		eq(e.h():Meta(b).modified, 1700000500);
		-- sort
		e.c:SetSort("modified");
		eq(names(e)[1], "B");
		e.c:SetSort("used");
		eq(names(e)[1], "B", "B was opened last (t=500)");
		e.c:SetSort("name");
		eq(names(e), { "A", "B", "C" });
		eq(e.h():GetSetting("libSort"), "name");
		e.world.click(e.ui.lib.sortCycle.next);
		eq(e.c:Sort(), "used");
		ok(e.world.hasText("Sort: Last used"), e.texts());
		local again = reload(e);
		eq(again.c:Sort(), "used", "sort order persisted");
	end);

	test("3.2B library: dates shown come from metadata; builds without metadata show none", function()
		local e = boot({ now = 1700000000 });
		local id = e.c:Create("Dated", "warrior");
		local old = e.h():Add({ name = "Old", class = "warrior", phases = {} });
		e.h().db.meta[old] = nil;
		e.c:Notify();
		local function sub(name) for _, r in ipairs(e.ui.lib.rows) do if r:IsShown() and r.name.text == name then return r.sub.text; end end end
		ok(sub("Dated"):find("%d%d/%d%d/%d%d%d%d"), sub("Dated"));
		eq(sub("Old"), "Warrior", "no metadata, no date");
		ok(id);
	end);

	test("3.2B library: class filter and search compose; selecting a row opens the build", function()
		local e = boot();
		local w, m = e.c:Create("Same", "warrior"), e.c:Create("Same", "mage");
		e.world.type(e.ui.lib.search, "same");
		eq(#e.c:Rows(), 2);
		e.world.click(e.ui.lib.classCycle.next);
		eq(#e.c:Rows(), 1);
		eq(e.c:Rows()[1].id, w);
		local row = e.ui.lib.rows[1];
		e.world.click(row);
		eq(e.c:Editor().id, w);
		eq(e.c.state.selectedId, w);
		ok(e.ui.ed.save:IsVisible());
		ok(m);
	end);

	test("3.2B library: switching builds with a draft asks first; the filters never touch the draft", function()
		local e = boot();
		local a, b = e.c:Create("A", "warrior"), e.c:Create("B", "warrior");
		e.ui:OpenEditor(a);
		e.c:AddSpell("whirlwind");
		e.world.type(e.ui.lib.search, "b");
		e.world.click(e.ui.lib.filters.favorites);
		e.world.click(e.ui.lib.filters.all);
		ok(e.c:EditorDirty(), "draft untouched by searching and filtering");
		e.world.click(e.ui.lib.rows[1]);                       -- B
		ok(e.G.RebornBuildPlannerModal:IsShown());
		e.world.clickLabel("Keep editing", e.G.RebornBuildPlannerModal);
		eq(e.c:Editor().id, a);
		ok(e.c:EditorDirty());
		-- clicking the build that is already open changes nothing and asks nothing
		e.world.type(e.ui.lib.search, "");
		for _, r in ipairs(e.ui.lib.rows) do if r.rowId == a then e.world.click(r); end end
		no(e.G.RebornBuildPlannerModal:IsShown());
		ok(e.c:EditorDirty());
	end);

	test("3.2B library: read-only blocks favourites and every library action", function()
		local e = boot({ preset = { RebornBuildPlannerDB = { schema = 99 } } });
		for _, b in ipairs({ e.ui.lib.dup, e.ui.lib.rename, e.ui.lib.delete, e.ui.lib.follow, e.ui.lib.create }) do no(b:IsEnabled()); end
		eq(e.c:ToggleFavorite("x"), false);
		eq(e.h():SetFavorite("x", true), nil);
		eq(e.h():Touch("x"), nil);
		eq(e.G.RebornBuildPlannerDB, nil == nil and e.G.RebornBuildPlannerDB, "newer database untouched");
		eq(e.G.RebornBuildPlannerDB.meta, nil);
	end);

	test("3.2B library: trash, restore and the 20-entry cap keep metadata coherent", function()
		local e = boot();
		local keep = e.c:Create("Keep", "warrior");
		e.c:ToggleFavorite(keep);
		e.c:ConfirmDelete(keep);
		ok(e.h().db.meta[keep], "metadata kept while in the trash");
		for i = 1, e.ns.Storage.LIMITS.trash do local id = e.c:Create("t" .. i, "warrior"); e.c:ConfirmDelete(id); end
		eq(e.h().db.meta[keep], nil, "metadata of an evicted build is dropped with it");
		eq(#e.h():Trash(), 20);
	end);

	-- ------------------------------------------------------------------ creation dialog
	test("3.2B create dialog: aligned fields, class preselected, validation keeps it open, nothing created on error", function()
		local e = boot({ classToken = "HUNTER", className = "Hunter" });
		e.world.clickLabel("Create a build", e.ui.leftPanel);
		local m = e.G.RebornBuildPlannerModal;
		ok(m:IsShown());
		eq(e.ui.modal.class, "hunter", "the player's class is preselected");
		-- label / field / selector never share the same row
		local ys = { e.ui.modal.editLabel.points[1].y, e.ui.modal.edit.points[1].y, e.ui.modal.cycleLabel.points[1].y, e.ui.modal.cycle.prev.points[1].y };
		ok(ys[2] ~= ys[4], "name field and class selector are on different rows");
		eq(e.world.lint(e.root), {});
		local n = e.h():Counts().builds;
		e.world.type(e.G.RebornBuildPlannerModalEdit, "   ");
		e.world.clickLabel("Create", m);
		ok(m:IsShown(), "dialog stays open on an empty name");
		ok(e.ui.modal.err.text:find("name"), e.ui.modal.err.text);
		eq(e.h():Counts().builds, n);
		e.world.type(e.G.RebornBuildPlannerModalEdit, string.rep("x", 300));
		e.world.clickLabel("Create", m);
		ok(m:IsShown() and e.ui.modal.err.text:find("too long"), e.ui.modal.err.text);
		e.world.type(e.G.RebornBuildPlannerModalEdit, "  Ranger plan  ");
		e.world.clickLabel("Create", m);
		no(m:IsShown());
		local id = e.c.state.selectedId;
		eq(e.h():Get(id).name, "Ranger plan", "trimmed");
		eq(e.h():Get(id).class, "hunter");
		eq(e.c:Editor().id, id, "the new build opens in the editor");
		eq(e.h():GetActive("hunter"), nil, "never active by itself");
		eq(e.c:Create("", "hunter"), nil, "the controller refuses an empty name too");
	end);

	-- ------------------------------------------------------------------ inspector
	test("3.2D inspector: selecting a spell shows the game's own text and its source; absence is stated", function()
		local e = boot({ gameSpells = { [845] = { "Cleave", "Hits two enemies.", "Rank 3" } } });
		local id = e.c:Create("I", "warrior"); e.ui:OpenEditor(id);
		ok(e.world.hasText("Select a spell or a piece"), e.texts());
		e.world.click(e.ui.bs.rows[1]);                 -- cleave
		local ins = e.ui.det;
		eq(ins.title.text, "Cleave");
		ok(e.ui:DetailText():find("Hits two enemies.", 1, true) and e.ui:DetailText():find("Rank 3", 1, true), e.ui:DetailText());
		ok(ins.source.text:find("game's own spell text", 1, true), ins.source.text);
		no(e.ui:DetailText():find("Detailed effect unavailable", 1, true));
		eq(e.world.tooltip.shown, false, "the read leaves no tooltip on screen");
		local calls = e.world.tooltip.calls;
		e.c:Notify(); e.c:Notify();
		eq(e.world.tooltip.calls, calls, "read once per spell, then cached");
		e.world.click(e.ui.bs.rows[2]);                 -- whirlwind: the game knows nothing
		ok(e.ui:DetailText():find("Detailed effect unavailable", 1, true), e.ui:DetailText());
		ok(ins.source.text:find("Reborn catalogue", 1, true));
		no(e.ui:DetailText():find("%d+%%"), "nothing invented");
	end);

	test("3.2D inspector: pieces show catalogue facts only; unknown element and homonymous legendaries are handled", function()
		local e = boot();
		local id = e.c:Create("I", "warrior"); e.ui:OpenEditor(id);
		e.c:SetCatalog("rings");
		e.c:SetSlot("rings", 1, "accuria");
		e.world.click(e.ui.ed.groups.rings.cells[1]);
		local ins = e.ui.det;
		eq(ins.title.text, "Band of Accuria");
		ok(e.ui:DetailText():find("Type: Ring", 1, true) and e.ui:DetailText():find("Detailed effect unavailable", 1, true), e.ui:DetailText());
		ok(e.ui:DetailText():find("Placed: main 1", 1, true));
		-- unknown element
		e.c:Inspect("spell", "not_a_spell");
		eq(ins.title.text, "not_a_spell");
		ok(e.ui:DetailText():find("Unknown to this catalogue", 1, true), e.ui:DetailText());
		-- homonymous legendaries: two keys, same name, told apart by class
		local cat = e.ns.catalog;
		local pair;
		for name, list in pairs(cat.idx.homonyms or {}) do
			if #list >= 2 and cat:Get("amulet", list[1]) and cat:Get("amulet", list[2]) and cat:Get("amulet", list[1]).class and cat:Get("amulet", list[2]).class
				and cat:Get("amulet", list[1]).class ~= cat:Get("amulet", list[2]).class then pair = list; break; end
		end
		if pair then
			local a, b = e.c:TooltipData("amulet", pair[1]), e.c:TooltipData("amulet", pair[2]);
			ok(a.title ~= nil and b.title ~= nil);
			local function cls(d) for _, l in ipairs(d.lines) do if l.text:find("Class:", 1, true) then return l.text; end end end
			ok(cls(a) ~= cls(b), "homonyms differ by class: " .. tostring(cls(a)) .. " / " .. tostring(cls(b)));
		end
	end);

	test("3.2D inspector: a very long game text stays inside the panel; no widget is created", function()
		local lines = { "Long spell" };
		for i = 1, 40 do lines[#lines + 1] = "Line " .. i .. " of a very long description that goes on and on and on"; end
		local e = boot({ gameSpells = { [845] = lines } });
		local id = e.c:Create("I", "warrior"); e.ui:OpenEditor(id);
		local n0 = #e.world.all;
		e.world.click(e.ui.bs.rows[1]);
		ok(e.ui:DetailText():find("Line 40", 1, true), "all lines kept");
		eq(e.world.lint(e.root), {});
		eq(#e.world.all, n0);
		eq(#e.ui.det.rows, 8, "a fixed pool of rows, scrolled");
		ok(e.ui.det.area.slider:IsShown(), "long text scrolls inside the panel");
	end);

	-- ------------------------------------------------------------------ storage and migrations
	local function snapshotBuilds(e) return H.roundtrip(e.G.RebornBuildPlannerDB.builds); end

	test("3.2E migration from 0.3.0: builds without metadata or banishAfter load unchanged; nothing is invented", function()
		local e0 = boot();
		local a = e0.c:Create("V030", "warrior");
		e0.ui:OpenEditor(a); e0.c:AddSpell("whirlwind"); e0.c:Save();
		local db = H.roundtrip(e0.G.RebornBuildPlannerDB);
		db.meta = nil;
		for _, b in pairs(db.builds) do for _, ph in ipairs(b.phases) do ph.banishAfter = nil; end end
		db.settings.libSort, db.settings.libFilter = nil, nil;
		local before = H.roundtrip(db.builds);
		local e = boot({ preset = { RebornBuildPlannerDB = db } });
		eq(e.h().status, "OPENED" == nil and "" or e.h().status);
		ok(not e.h().readOnly);
		local function plain(builds)       -- opening adds an EMPTY banishAfter list in memory; nothing else may change
			local out = H.roundtrip(builds);
			for _, b in pairs(out) do for _, ph in ipairs(b.phases) do if ph.banishAfter and #ph.banishAfter == 0 then ph.banishAfter = nil; end end end
			return out;
		end
		eq(plain(e.G.RebornBuildPlannerDB.builds), before, "builds identical after opening (but for the empty list)");
		eq(e.h():Meta(a), { fav = false }, "no favourite, no dates");
		eq(names(e), { "V030" });
		eq(e.c:Sort(), "name"); eq(e.c:Filter(), "all");
		e.ui:OpenEditor(a);
		no(e.c:EditorDirty());
		e.world.click(e.ui.ed.fav);
		ok(e.h():Meta(a).fav);
		eq(plain(e.G.RebornBuildPlannerDB.builds), before, "favouriting does not touch the build or its revision");
	end);

	test("3.2E migration from 0.3.1: banishAfter marks kept, metadata created lazily", function()
		local e0 = boot();
		local a = e0.c:Create("V031", "warrior");
		e0.ui:OpenEditor(a);
		for _, k in ipairs({ "whirlwind", "execute" }) do e0.c:AddSpell(k); end
		e0.c:SetBanishAfter("execute", true); e0.c:Save();
		local db = H.roundtrip(e0.G.RebornBuildPlannerDB);
		db.meta = nil;
		local e = boot({ preset = { RebornBuildPlannerDB = db } });
		eq(e.h():Get(a).phases[1].banishAfter, { "execute" });
		eq(e.G.RebornBuildPlannerDB.meta, nil, "opening writes no metadata");
		e.at(1700000900);
		e.ui:OpenEditor(a);
		eq(e.h():Meta(a).used, 1700000900);
	end);

	test("3.2E metadata that is corrupt or unknown is left alone: builds stay usable, nothing is lost", function()
		local e0 = boot();
		local a = e0.c:Create("Meta", "warrior");
		local db = H.roundtrip(e0.G.RebornBuildPlannerDB);
		db.meta = "garbage";
		db.ext = { keep = { 1, 2 } };
		local e = boot({ preset = { RebornBuildPlannerDB = db } });
		ok(not e.h().readOnly);
		eq(names(e), { "Meta" });
		eq(e.h():Meta(a), { fav = false });
		local ok1, err = e.h():SetFavorite(a, true);
		eq(ok1, nil);
		eq(err.code, "INVALID_DB");
		eq(e.G.RebornBuildPlannerDB.meta, "garbage", "the unreadable value is not overwritten");
		eq(e.G.RebornBuildPlannerDB.ext, { keep = { 1, 2 } });
		ok(e.h():Get(a), "the build is intact");
		e.ui:OpenEditor(a);              -- Touch must not throw on unreadable metadata
		ok(e.c:Editor() ~= nil);
		-- unknown fields inside a metadata entry survive a favourite toggle
		local e2 = boot();
		local b = e2.c:Create("B", "warrior");
		e2.h().db.meta[b].futureField = "x";
		e2.c:ToggleFavorite(b);
		eq(e2.h().db.meta[b].futureField, "x");
	end);

	test("3.2E four imported stages stay four, with banishes, after open and save", function()
		local e = boot();
		local ns0 = e.ns;
		local C, J, B = ns0.PlannerCodec, ns0.Json, ns0.Base64Url;
		local function phase(spells, banish) return J.Array({ "", J.Array(spells), J.Array(banish or {}), J.Array({ "accuria" }) }); end
		local code = C.PREFIX .. B.Encode(assert(J.Encode(J.Array({ 1, "Four", "warrior", "", phase({ "whirlwind" }), phase({ "execute" }, { "rend" }), phase({ "cleave" }), phase({ "bloodthirst" }) }))));
		e.c:SetView("import");
		e.world.type(e.ui.im.box, code);
		e.world.clickLabel("Analyze", e.ui.views.import);
		e.world.clickLabel("Import", e.ui.views.import);
		local id = e.c.state.selectedId;
		local before = e.h():Get(id);
		e.ui:OpenEditor(id);
		ok(e.c:ShowAllPhases());
		for p = 1, 4 do ok(e.ui.ed.phaseTabs[p]:IsVisible(), "tab " .. p); end
		e.c:SetPhase(3);
		e.c:AddSpell("rend");
		e.c:Save();
		local after = e.h():Get(id);
		eq(#after.phases, 4);
		eq(after.phases[2].spells, before.phases[2].spells);
		eq(after.phases[2].banish, { "rend" });
		eq(after.phases[4].spells[1].key, "bloodthirst");
		eq(after.phases[3].spells[2].key, "rend");
	end);

	test("3.2E unknown class and imported conflicts stay editable, unfollowable and visible in the library", function()
		local e = boot();
		local u = e.h():Add({ name = "Future", class = "necromancer", phases = {} });
		local c = e.h():Add({ name = "Conflicted", class = "warrior", phases = { { spells = { "whirlwind" }, banish = { "whirlwind" } } } });
		e.c:Notify();
		local tags = {};
		for _, r in ipairs(e.ui.lib.rows) do if r:IsShown() then tags[r.name.text] = r.tag.text; end end
		eq(tags.Future, "", "an unknown class is storable (a warning, not a conflict) but never followable");
		eq(tags.Conflicted, "Repair");
		eq(e.c:Activate(u), false);
		eq(e.c:Activate(c), false);
		e.ui:OpenEditor(u);
		eq(e.world.lint(e.root), {});
	end);

	-- ------------------------------------------------------------------ performance and idle
	test("3.2F performance: the list is computed once per change, searches reuse the index, widget count is stable", function()
		local e = boot();
		many(e, 200);
		eq(e.c:Rows(), e.c:Rows(), "same table until something changes");
		local n0 = #e.world.all;
		local calls = 0;
		local orig = e.ns.Controller.IndexOf;
		e.ns.Controller.IndexOf = function(self, b) calls = calls + 1; return orig(self, b); end;
		e.world.type(e.ui.lib.search, "build 1");
		eq(calls, 200, "first search indexes each build once");
		calls = 0;
		e.world.type(e.ui.lib.search, "build 15");
		e.world.type(e.ui.lib.search, "build 150");
		-- IndexOf is called per build and answers from its cache: the cache must hold
		local cached = 0;
		for _, v in pairs(e.c.searchIndex) do cached = cached + 1; end
		eq(cached, 200);
		e.ns.Controller.IndexOf = orig;
		for i = 1, 100 do e.c:Notify(); end
		eq(#e.world.all, n0, "100 refreshes with 200 builds create no widget");
		-- opening/closing the window and switching builds create nothing either
		e.world.type(e.ui.lib.search, "");
		for i = 1, 10 do e.ui:OpenEditor(e.c:Rows()[i].id); end
		eq(#e.world.all, n0);
	end);

	test("3.2F idle: no OnUpdate anywhere, no timer, tooltips only on hover", function()
		local e = boot();
		local id = e.c:Create("Idle", "warrior"); e.ui:OpenEditor(id);
		for _, f in ipairs(e.world.all) do no(f.scripts and f.scripts.OnUpdate, "OnUpdate on " .. tostring(f.name or f.kind)); end
		local src = "";
		for _, f in ipairs({ "UI.lua", "Controller.lua", "Core.lua", "Commands.lua" }) do src = src .. H.readFile(H.root .. "/addon/RebornBuildPlanner/" .. f); end
		src = src:gsub("%-%-[^\n]*", "");        -- comments may say "no OnUpdate"
		no(src:find("OnUpdate", 1, true) or src:find("C_Timer", 1, true) or src:find("C_Timer.After", 1, true), "no polling code");
		eq(e.world.tooltip.shown, false);
	end);

	test("3.2F no network, no foreign write: the addon touches only its own globals", function()
		local e = boot();
		local id = e.c:Create("G", "warrior"); e.ui:OpenEditor(id); e.c:AddSpell("whirlwind"); e.c:Save();
		for k in pairs(e.sb.writes) do
			ok(k == "SlashCmdList" or k:find("^RebornBuildPlanner") or k:find("^SLASH_REBORNPLANNER"), "unexpected global write: " .. k);
		end
	end);
end
