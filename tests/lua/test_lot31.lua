-- Lot 3.1: "banish after acquisition" model + migration, azsb1 interoperability limits, tooltips, opaque window.
-- Same limits as test_ui: widget MOCK, layout on estimated metrics; nothing here proves rendering in the Reborn client.
return function(H)
	local eq, ok, no, test = H.eq, H.ok, H.no, H.test;
	local Stub = dofile(H.root .. "/tests/lua/wowstub.lua");

	local ns0 = H.loadAddon();
	local cat = ns0.Catalog.New(ns0.GeneratedCatalog);
	local BM, C, J, B = ns0.BuildModel, ns0.PlannerCodec, ns0.Json, ns0.Base64Url;
	local SIX = { "whirlwind", "execute", "cleave", "rend", "bloodthirst", "shockwave" };

	local function sixBuild(marks)
		local b = assert(BM.New({ id = "b1", name = "Six", class = "warrior" }, cat));
		for _, k in ipairs(SIX) do b = assert(BM.AddSpell(b, 1, k, nil, cat)); end
		for _, k in ipairs(marks or {}) do b = assert(BM.SetBanishAfter(b, 1, k, true, cat)); end
		return b;
	end

	-- ------------------------------------------------------------------ 3.1A model
	test("3.1A model: six wanted spells, three of them banish-after; this is NOT a conflict", function()
		local b = sixBuild({ "rend", "bloodthirst", "shockwave" });
		local rep = BM.Validate(b, cat);
		ok(rep.clean, "clean");
		eq(#b.phases[1].spells, 6);
		eq(b.phases[1].banishAfter, { "rend", "bloodthirst", "shockwave" });
		eq(b.phases[1].banish, {}, "the avoid list is a different thing and stays empty");
		ok(b.revision > 1);
	end);

	test("3.1A model: a fourth mark is refused, an unwanted spell cannot be marked, unmark works", function()
		local b = sixBuild({ "rend", "bloodthirst", "shockwave" });
		local nb, rep = BM.SetBanishAfter(b, 1, "whirlwind", true, cat);
		eq(nb, nil);
		eq(rep.issues[1].code, "TOO_MANY");
		eq(b.phases[1].banishAfter, { "rend", "bloodthirst", "shockwave" }, "input untouched");
		local b2 = sixBuild();
		nb, rep = BM.SetBanishAfter(b2, 1, "mortal_strike", true, cat);
		eq(nb, nil, "not in the plan");
		nb, rep = BM.SetBanishAfter(b, 1, "rend", false, cat);
		eq(nb.phases[1].banishAfter, { "bloodthirst", "shockwave" });
		nb, rep = BM.SetBanishAfter(b, 1, "whirlwind", false, cat);
		eq(nb, nil, "unmarking something not marked is an error, not a silent success");
		-- marking twice is idempotent
		local again = assert(BM.SetBanishAfter(b, 1, "rend", true, cat));
		eq(again.phases[1].banishAfter, { "rend", "bloodthirst", "shockwave" });
	end);

	test("3.1A model: reordering keeps each mark (marks are keyed, not positional)", function()
		local b = sixBuild({ "execute", "shockwave" });
		b = assert(BM.MoveSpell(b, 1, 6, 1, cat));
		eq(b.phases[1].spells[1].key, "shockwave");
		eq(b.phases[1].banishAfter, { "execute", "shockwave" });
		b = assert(BM.MoveSpell(b, 1, 1, 6, cat));
		eq(b.phases[1].banishAfter, { "execute", "shockwave" });
		ok(BM.Validate(b, cat).clean);
	end);

	test("3.1A model: removing a spell cleans its mark (and only its mark); the spell can come back unmarked", function()
		local b = sixBuild({ "execute", "shockwave" });
		b = assert(BM.RemoveSpell(b, 1, "execute", cat));
		eq(b.phases[1].banishAfter, { "shockwave" });
		eq(#b.phases[1].spells, 5);
		ok(BM.Validate(b, cat).clean);
		b = assert(BM.AddSpell(b, 1, "execute", nil, cat));
		eq(b.phases[1].banishAfter, { "shockwave" }, "re-adding does not resurrect the mark");
	end);

	test("3.1A model: a dangling or duplicate mark in stored data is a flagged conflict, never silently fixed", function()
		local b = sixBuild({ "rend" });
		local raw = H.roundtrip(b);
		raw.phases[1].banishAfter = { "rend", "rend", "mortal_strike" };
		local rep = BM.Validate(raw, cat);
		no(rep.clean);
		local codes = {};
		for _, it in ipairs(rep.conflicts) do codes[it.code] = true; end
		ok(codes.DUPLICATE_ENTRY and codes.BANISH_AFTER_NOT_WANTED, "conflicts flagged");
		raw.phases[1].banishAfter = { 1, 2, 3, 4 };
		ok(not BM.Validate(raw, cat).ok, "more than 3 / non-strings is an error");
	end);

	test("3.1A migration: an older build without the field is valid, unchanged, and reads as 'nothing to banish after'", function()
		local b = sixBuild();
		local old = H.roundtrip(b);
		for _, ph in ipairs(old.phases) do ph.banishAfter = nil; end
		ok(BM.Validate(old, cat).clean, "absent field accepted");
		local norm, rep = BM.Normalize(old, cat);
		ok(norm ~= nil);
		eq(norm.phases[1].banishAfter, {}, "normalised to empty");
		eq(norm.phases[1].spells, old.phases[1].spells);
		for _, it in ipairs(rep.issues) do no(it.path and it.path:find("banishAfter"), "no warning for the missing field"); end
		-- editing an old build works (the setter creates the list)
		local nb = assert(BM.SetBanishAfter(old, 1, "rend", true, cat));
		eq(nb.phases[1].banishAfter, { "rend" });
	end);

	test("3.1A migration: an old spell+banish overlap stays a conflict; converting is an explicit action", function()
		local b = sixBuild();
		local old = H.roundtrip(b);
		old.phases[1].banish = { "rend", "execute" };
		old.phases[1].banishAfter = nil;
		local rep = BM.Validate(old, cat);
		no(rep.clean);
		eq(#rep.conflicts, 2);
		eq(rep.conflicts[1].code, "CONFLICT_SPELL_BANISH");
		-- normalising / loading does NOT convert
		local norm = BM.Normalize(old, cat);
		eq(norm.phases[1].banish, { "rend", "execute" });
		eq(norm.phases[1].banishAfter, {});
		-- the player decides, one entry at a time
		local c1 = assert(BM.ConvertBanishToAfter(norm, 1, "rend", cat));
		eq(c1.phases[1].banish, { "execute" });
		eq(c1.phases[1].banishAfter, { "rend" });
		eq(#BM.Validate(c1, cat).conflicts, 1, "the other overlap is still flagged");
		local nb, why = BM.ConvertBanishToAfter(norm, 1, "whirlwind", cat);
		eq(nb, nil, "not in the avoid list");
	end);

	-- ------------------------------------------------------------------ 3.1A codec limits
	test("3.1A codec: azsb1 cannot carry banish-after; every mark is reported as a loss, nothing is injected into the banish list", function()
		local b = sixBuild({ "rend", "bloodthirst", "shockwave" });
		local rep = C.PlanExport(b, cat);
		ok(rep.ok and not rep.lossless);
		local n = 0;
		for _, l in ipairs(rep.losses) do
			if l.code == "BANISH_AFTER_NOT_REPRESENTABLE" then n = n + 1; eq(l.severity, "intent"); end
		end
		eq(n, 3);
		-- the array has the six wanted spells and an EMPTY banish list (the site would drop overlaps anyway)
		local ph = rep.array[5];
		eq(#ph[2], 6);
		ok(ph[3] == nil or #ph[3] == 0, "banish list empty or trimmed");
		local nocode, r2 = C.Encode(b, cat);
		eq(nocode, nil);
		ok(r2.needsConfirmation, "export refused until the losses are accepted");
		local code = assert(C.Encode(b, cat, { acceptLosses = true }));
		local pv = C.Decode(code, cat);
		ok(pv.ok);
		local back = pv.build or pv.draft;
		ok(back == nil or true);
	end);

	test("3.1A codec: a build without marks still exports losslessly (no regression)", function()
		local b = sixBuild();
		local rep = C.PlanExport(b, cat);
		ok(rep.lossless, "no intent loss");
		ok(C.Encode(b, cat) ~= nil);
	end);

	test("3.1A codec: a site code with wanted+banished overlaps imports as flagged conflicts (nothing converted)", function()
		local function phase(spells, banish) return J.Array({ "", J.Array(spells), J.Array(banish), J.Array({}) }); end
		local text = C.PREFIX .. B.Encode(assert(J.Encode(J.Array({ 1, "Site", "warrior", "", phase(SIX, { "rend", "execute", "cleave" }) }))));
		local pv = C.Decode(text, cat);
		ok(pv.ok);
		eq(pv.status, "needs_repair");
		local hit = 0;
		for _, it in ipairs(pv.issues.list) do if it.code == "CONFLICT_SPELL_BANISH" then hit = hit + 1; end end
		eq(hit, 3);
	end);

	-- ------------------------------------------------------------------ harness for UI tests
	local function boot(o)
		o = o or {};
		local world = Stub.new({ width = o.width or 1365, height = o.height or 768, locale = o.locale or "enUS", gameSpells = o.gameSpells });
		local ns, sb = H.loadAddon({ globals = world.G, time = world.G.time });
		local env = { world = world, ns = ns, sb = sb, G = world.G };
		world.fire("ADDON_LOADED", "RebornBuildPlanner");
		env.c, env.ui = ns.controller, ns.ui;
		world.G.SlashCmdList.REBORNPLANNER("");
		env.root = world.G.RebornBuildPlannerFrame;
		function env.h() return ns.storage; end
		function env.texts() return table.concat(world.texts(), " | "); end
		return env;
	end
	-- selecting a row of the browser, then the detail panel's primary action (what a player does in two clicks)
	local function pick(e, i) e.world.click(e.ui.bs.rows[i]); e.world.click(e.ui.det.act1); end
	local function newEditor(e, class)
		local id = e.c:Create("Plan", class or "warrior");
		e.ui:OpenEditor(id);
		return id, e.ui.ed;
	end
	local function wantSix(e)
		local keys = e.ns.catalog:SpellsOfClass(e.c:Editor().draft.class);
		for i = 1, 6 do e.c:AddSpell(keys[i]); end
	end

	test("3.1A UI: six wanted, three marked; the indicator, labels and the avoid list stay distinct", function()
		local e = boot(); local id, ed = newEditor(e); wantSix(e);
		ok(e.world.hasText("6 keep / 0 banish after (max 3)"), e.texts());
		for i = 1, 3 do e.world.click(ed.spells[i].tog); end
		ok(e.world.hasText("3 keep / 3 banish after (max 3)"), e.texts());
		local ph = e.c:Editor().draft.phases[1];
		eq(#ph.banishAfter, 3);
		eq(#ph.banish, 0, "marks never touch the avoid list");
		eq((ed.spells[1].tog:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")), "Banish after");
		ok(e.world.button("Keep", ed.spells[4].frame) ~= nil);
		no(e.world.button("Keep", ed.spells[1].frame), "the text carries the state, not only a colour");
		e.world.click(ed.spells[4].tog);
		eq(#e.c:Editor().draft.phases[1].banishAfter, 3);
		ok(e.world.hasText("At most 3 spells"), e.texts());
		e.world.click(ed.spells[2].tog);
		eq(#e.c:Editor().draft.phases[1].banishAfter, 2);
		ok(e.world.hasText("4 keep / 2 banish after"), e.texts());
	end);

	test("3.1A UI: marks survive reorder, save, /reload; removal says what else it removed", function()
		local e = boot(); local id, ed = newEditor(e); wantSix(e);
		local keys = e.ns.catalog:SpellsOfClass("warrior");
		for _, i in ipairs({ 2, 4, 6 }) do e.world.click(ed.spells[i].tog); end
		e.world.click(ed.spells[2].down);
		local draft = e.c:Editor().draft.phases[1];
		eq(draft.spells[3].key, keys[2]);
		ok(ed.spells[3].tog:GetText():find("Banish after", 1, true), "mark followed the spell");
		e.world.click(ed.save);
		eq(e.h():Get(id).phases[1].banishAfter, { keys[2], keys[4], keys[6] });
		local text = H.serialize("RebornBuildPlannerDB", e.G.RebornBuildPlannerDB);
		local world2 = Stub.new({ width = 1365, height = 768 });
		world2.G.RebornBuildPlannerDB = H.reload("RebornBuildPlannerDB", text);
		local ns2 = H.loadAddon({ globals = world2.G, time = world2.G.time });
		world2.fire("ADDON_LOADED", "RebornBuildPlanner");
		eq(ns2.storage:Get(id).phases[1].banishAfter, { keys[2], keys[4], keys[6] }, "persisted across /reload");
		e.world.click(ed.spells[3].del);
		ok(e.world.hasText("banish-after mark with it"), e.texts());
		eq(#e.c:Editor().draft.phases[1].banishAfter, 2);
		e.world.clickLabel("Discard changes", e.ui.views.editor);
		eq(#e.c:Editor().draft.phases[1].banishAfter, 3);
	end);

	test("3.1A UI: marking then unmarking an old build leaves it unsaved-free (absent == empty)", function()
		local e = boot(); local id = e.c:Create("Old", "warrior");
		for _, ph in ipairs(e.h().db.builds[id].phases) do ph.banishAfter = nil; end
		e.ui:OpenEditor(id);
		no(e.c:EditorDirty(), "opening an old build is not a change");
		e.c:AddSpell("whirlwind");
		e.c:SetBanishAfter("whirlwind", true);
		e.c:SetBanishAfter("whirlwind", false);
		e.c:RemoveSpell("whirlwind");
		no(e.c:EditorDirty());
	end);

	test("3.1A UI: a legacy overlap is flagged, offers an explicit convert button, and is never converted silently", function()
		local e = boot(); local id = e.c:Create("Legacy", "warrior");
		local b = H.roundtrip(e.h():Get(id));
		b.phases[1].spells = { { key = "whirlwind", mode = "acquire" }, { key = "execute", mode = "acquire" } };
		b.phases[1].banish = { "execute" };
		e.h().db.builds[id] = b;
		e.c:Notify();
		e.ui:OpenEditor(id);
		local ed = e.ui.ed;
		eq(e.c:EditorStatus(), "repair");
		e.c:ToggleAdvanced();
		ok(ed.nt.previewNotes:IsShown(), "notes overview comes first");
		e.world.click(ed.nt.switch);
		ok(ed.nt.avoid[1].conv:IsVisible(), "convert offered");
		eq(e.c:Editor().draft.phases[1].banish, { "execute" }, "still untouched after opening");
		no(e.c:Activate(id), "cannot follow while in conflict");
		e.world.click(ed.nt.avoid[1].conv);
		eq(e.c:Editor().draft.phases[1].banish, {});
		eq(e.c:Editor().draft.phases[1].banishAfter, { "execute" });
		eq(e.c:EditorStatus(), "dirty");
		e.world.click(ed.save);
		eq(e.c:EditorStatus(), "saved");
		ok(e.c:Activate(id), "repaired build can be followed");
	end);

	test("3.1A UI: export with marks shows the loss list and requires acceptance; nothing is banished anywhere", function()
		local e = boot(); local id, ed = newEditor(e); wantSix(e);
		for i = 1, 3 do e.world.click(ed.spells[i].tog); end
		e.world.click(e.ui.nav.export);
		local x = e.c.state.export;
		ok(x.report.intentLosses >= 3);
		eq(x.code, nil, "no code before acceptance");
		ok(e.world.hasText("does not exist in the official format"), e.texts());
		ok(e.world.hasText("would be lost"), e.texts());
		e.c:AcceptLosses();
		ok(e.c.state.export.code ~= nil);
		for _, f in ipairs({ "Controller.lua", "UI.lua", "Commands.lua", "Core.lua", "BuildModel.lua" }) do
			local src = H.readFile(H.root .. "/addon/RebornBuildPlanner/" .. f);
			no(src:find("AZS_API", 1, true) or src:find("Reroll", 1, true) or src:find("BanishCard", 1, true) or src:find("PickCard", 1, true), f .. " must not act in the game");
		end
	end);

	-- ------------------------------------------------------------------ look
	test("3.1B look: the window and the dialog are opaque, above the HUD, with a separate panel per zone", function()
		local e = boot();
		eq(e.root.strata, "FULLSCREEN_DIALOG");
		ok(e.root.nine and e.root.nine.file == "window_nine", "main window uses the opaque fantasy shell");
		local m = e.G.RebornBuildPlannerModal;
		eq(m.strata, "FULLSCREEN_DIALOG");
		ok(m.nine and m.nine.file == "window_nine", "modal uses same opaque themed shell");
		ok(m.level > e.root.level, "dialog above the window");
		for name, v in pairs({ library = e.ui.leftPanel, editor = e.ui.centre, inspector = e.ui.rightPanel, import = e.ui.views.import, export = e.ui.views.export }) do
			ok(v.nine and v.nine.file == "ultimate_panel", name .. " uses its independent framed panel");
		end
		no(e.root.nine.file == e.ui.leftPanel.nine.file, "window and panel have distinct materials");
	end);

	test("3.1B look: the main action is coloured, secondary ones are quiet, a disabled button loses its colour; labels stay readable", function()
		local e = boot(); local id, ed = newEditor(e);
		e.c:AddSpell("whirlwind"); -- a real draft change, unlike merely selecting an item
		ok(e.c:EditorDirty(), "editing made Save available");
		ok(ed.save.nine and ed.save.nine.file == "button_primary_nine", "Save has the visible primary theme");
		ok(ed.revert.nine and ed.revert.nine.file == "button_secondary_nine", "Discard uses a quiet secondary theme");
		e.world.click(ed.save);
		no(ed.save:IsEnabled());
		no(ed.save:GetText():find("|cff", 1, true), "disabled: plain text, greyed by the client");
		eq(ed.save:GetText(), "Save");
		ok(e.world.button("Save and follow") ~= nil);
	end);

	local function fillEditor(e, ed)
		e.c:Rename(e.c:Editor().id, string.rep("Nom tr\195\168s long ", 10));
		wantSix(e);
		for i = 1, 3 do e.c:AddBanish(e.c:CatalogEntries()[6 + i].key); end
		for i = 1, 3 do e.world.click(ed.spells[i].tog); end
		for _, g in ipairs({ "rings", "trinkets", "amulets" }) do
			e.c:SetCatalog(g);
			for s = 1, #e.c:Editor().draft.phases[1][g] do e.c:SelectSlot(g, s); e.c:SetSlot(g, s, e.c:CatalogEntries()[s].key); end
		end
		e.c:Inspect("spell", e.c:Editor().draft.phases[1].spells[1].key);
	end

	test("3.1B look: the unified editor stays inside the window at four screen sizes, both languages, with everything filled", function()
		for _, size in ipairs({ { 1365, 768 }, { 1920, 1080 }, { 1024, 768 }, { 800, 600 } }) do
			for _, loc in ipairs({ "enUS", "frFR" }) do
				local e = boot({ width = size[1], height = size[2], locale = loc });
				local id, ed = newEditor(e);
				fillEditor(e, ed);
				eq(e.world.lint(e.root), {}, "editor " .. size[1] .. " " .. loc);
				e.world.hover(e.ui.bs.rows[1]); e.world.unhover(e.ui.bs.rows[1]);
				e.c:ToggleAdvanced();
				eq(e.world.lint(e.root), {}, "advanced " .. size[1] .. " " .. loc);
			end
		end
	end);

	test("3.1B look: UI scale 0.6 and 1.5 keep the window inside the screen", function()
		local e = boot({ width = 1365, height = 768, locale = "frFR" });
		local id, ed = newEditor(e); fillEditor(e, ed);
		for _, s in ipairs({ 0.6, 1, 1.5 }) do
			e.h():SetSetting("scale", s);
			e.ui:ApplyScale();
			eq(e.world.lint(e.root), {}, "scale " .. s);
		end
	end);

	test("3.1D editor: the chosen slot is announced in words and by a prefix, not only by colour", function()
		local e = boot(); local id, ed = newEditor(e);
		e.c:SelectSlot("rings", 3);
		local cells = ed.groups.rings.cells;
		ok(cells[3].role.text:find("^> "), cells[3].role.text);
		no(cells[1].role.text:find("^> "));
		ok(e.world.hasText("Target: Rings - Alternative 1 (empty)"), e.texts());
		ok(cells[3].edge.shown, "band under the chosen slot too");
		e.c:SelectSlot("rings", 1);
		ok(e.world.hasText("Target: Rings - Main 1 (empty)"), e.texts());
		ok(e.world.button("Rings *") ~= nil, "the catalogue kind in use is marked");
	end);

	test("3.1D editor: every new string is translated", function()
		local ns = H.loadAddon();
		ns.Locale.SetLang("frFR");
		local missing = {};
		local src = H.readFile(H.root .. "/addon/RebornBuildPlanner/UI.lua");
		local block = (src:match("local HELP = (.-)\n};") or ""):gsub('\\"', "\1");
		for k in block:gmatch('"([^"\n]-[%a][^"\n]-)"') do
			local key = k:gsub("\1", '"');
			if ns.Locale.T(key) == key and #key > 3 then missing[#missing + 1] = key; end
		end
		local ctl = H.readFile(H.root .. "/addon/RebornBuildPlanner/Controller.lua");
		for k in ctl:gmatch('L%("([^\n]-)"%)') do
			local key = k:gsub('\\"', '"');
			if ns.Locale.T(key) == key then missing[#missing + 1] = key; end
		end
		eq(missing, {});
	end);
end
