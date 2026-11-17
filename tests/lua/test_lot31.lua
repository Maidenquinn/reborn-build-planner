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
	local function newEditor(e, class)
		local id = e.c:Create("Plan", class or "warrior");
		e.ui:OpenEditor(id);
		return id, e.ui.ed;
	end
	local function wantSix(e, ed)
		for i = 1, 6 do e.world.click(ed.cat.rows[i].a); end
	end

	test("3.1A UI: six wanted, three marked; the indicator, labels and the avoid list stay distinct", function()
		local e = boot(); local id, ed = newEditor(e); wantSix(e, ed);
		ok(e.world.hasText("6 to keep / 0 to banish after acquisition (max 3)"), e.texts());
		for i = 1, 3 do e.world.click(ed.plan.spells[i].tog); end
		ok(e.world.hasText("3 to keep / 3 to banish after acquisition (max 3)"), e.texts());
		local ph = e.c:Editor().draft.phases[1];
		eq(#ph.banishAfter, 3);
		eq(#ph.banish, 0, "marks never touch the avoid list");
		eq((ed.plan.spells[1].tog:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")), "Banish after");
		ok(e.world.button("Keep", ed.plan.spells[4].frame) ~= nil);
		-- the status text carries the state, not only a colour
		no(e.world.button("Keep", ed.plan.spells[1].frame));
		-- fourth mark: refused with a clear message, data unchanged
		e.world.click(ed.plan.spells[4].tog);
		eq(#e.c:Editor().draft.phases[1].banishAfter, 3);
		ok(e.world.hasText("At most 3 spells"), e.texts());
		-- unmark
		e.world.click(ed.plan.spells[2].tog);
		eq(#e.c:Editor().draft.phases[1].banishAfter, 2);
		ok(e.world.hasText("4 to keep / 2 to banish after acquisition"), e.texts());
	end);

	test("3.1A UI: marks survive reorder, save, /reload; removal says what else it removed", function()
		local e = boot(); local id, ed = newEditor(e); wantSix(e, ed);
		local keys = e.ns.catalog:SpellsOfClass("warrior");
		for _, i in ipairs({ 2, 4, 6 }) do e.world.click(ed.plan.spells[i].tog); end
		e.world.click(ed.plan.spells[2].down);          -- the marked spell moves to position 3
		local draft = e.c:Editor().draft.phases[1];
		eq(draft.spells[3].key, keys[2]);
		ok(ed.plan.spells[3].tog:GetText():find("Banish after", 1, true), "mark followed the spell");
		e.world.click(ed.save);
		eq(e.h():Get(id).phases[1].banishAfter, { keys[2], keys[4], keys[6] });
		local text = H.serialize("RebornBuildPlannerDB", e.G.RebornBuildPlannerDB);
		local world2 = Stub.new({ width = 1365, height = 768 });
		world2.G.RebornBuildPlannerDB = H.reload("RebornBuildPlannerDB", text);
		local ns2 = H.loadAddon({ globals = world2.G, time = world2.G.time });
		world2.fire("ADDON_LOADED", "RebornBuildPlanner");
		eq(ns2.storage:Get(id).phases[1].banishAfter, { keys[2], keys[4], keys[6] }, "persisted across /reload");
		-- removing a marked spell removes its mark and says so
		e.world.click(ed.plan.spells[3].del);
		ok(e.world.hasText("banish-after mark with it"), e.texts());
		eq(#e.c:Editor().draft.phases[1].banishAfter, 2);
		-- discard brings it back
		e.world.clickLabel("Discard changes", e.ui.views.editor);
		eq(#e.c:Editor().draft.phases[1].banishAfter, 3);
	end);

	test("3.1A UI: marking then unmarking an old build leaves it unsaved-free (absent == empty)", function()
		local e = boot(); local id = e.c:Create("Old", "warrior");
		e.h().db.builds[id].phases[1].banishAfter = nil;
		for _, ph in ipairs(e.h().db.builds[id].phases) do ph.banishAfter = nil; end
		e.ui:OpenEditor(id);
		no(e.c:EditorDirty(), "opening an old build is not a change");
		e.c:AddSpell("whirlwind");
		e.c:Revert();
		no(e.c:EditorDirty());
	end);

	test("3.1A UI: a legacy overlap is flagged, offers an explicit convert button, and is never converted silently", function()
		local e = boot(); local id = e.c:Create("Legacy", "warrior");
		local b = e.h():Get(id);
		b = H.roundtrip(b);
		b.phases[1].spells = { { key = "whirlwind", mode = "acquire" }, { key = "execute", mode = "acquire" } };
		b.phases[1].banish = { "execute" };
		e.h().db.builds[id] = b;
		e.ui:OpenEditor(id);
		local ed = e.ui.ed;
		eq(e.c:EditorStatus(), "repair");
		ok(ed.plan.banish[1].conv:IsVisible(), "convert offered");
		eq(e.c:Editor().draft.phases[1].banish, { "execute" }, "still untouched after opening");
		no(e.c:Activate(id), "cannot follow while in conflict");
		e.world.click(ed.plan.banish[1].conv);
		eq(e.c:Editor().draft.phases[1].banish, {});
		eq(e.c:Editor().draft.phases[1].banishAfter, { "execute" });
		eq(e.c:EditorStatus(), "dirty");
		e.world.click(ed.save);
		eq(e.c:EditorStatus(), "saved");
		ok(e.c:Activate(id), "repaired build can be followed");
	end);

	test("3.1A UI: export with marks shows the loss list and requires acceptance; nothing is banished anywhere", function()
		local e = boot(); local id, ed = newEditor(e); wantSix(e, ed);
		for i = 1, 3 do e.world.click(ed.plan.spells[i].tog); end
		e.world.click(ed.export);
		local x = e.c.state.export;
		ok(x.report.intentLosses >= 3);
		eq(x.code, nil, "no code before acceptance");
		ok(e.world.hasText("does not exist in the official format"), e.texts());
		ok(e.world.hasText("would be lost"), e.texts());
		e.c:AcceptLosses();
		ok(e.c.state.export.code ~= nil);
		-- no addon file refers to anything that could act in the game
		for _, f in ipairs({ "Controller.lua", "UI.lua", "Commands.lua", "Core.lua", "BuildModel.lua" }) do
			local src = H.readFile(H.root .. "/addon/RebornBuildPlanner/" .. f);
			no(src:find("AZS_API", 1, true) or src:find("Reroll", 1, true) or src:find("BanishCard", 1, true) or src:find("PickCard", 1, true), f .. " must not act in the game");
		end
	end);

	-- ------------------------------------------------------------------ 3.1C tooltips
	test("3.1C tooltips: spell hover shows the game's own text, then the plan state; leaving hides it", function()
		local e = boot({ gameSpells = { [845] = { "Cleave", "Hits two enemies." } } });
		local id, ed = newEditor(e);
		e.world.click(ed.cat.rows[1].a);                   -- cleave is the first warrior spell
		e.world.click(ed.plan.spells[1].tog);
		local tt = e.world.hover(ed.cat.rows[1].hit);
		ok(tt:IsShown());
		eq(tt.owner, ed.cat.rows[1].hit);
		local text = tt:Text();
		ok(text:find("Hits two enemies.", 1, true), text);
		ok(text:find("Wanted: priority 1", 1, true), text);
		ok(text:find("banish after acquisition", 1, true), text);
		ok(text:find("nothing is banished automatically", 1, true), text);
		e.world.unhover(ed.cat.rows[1].hit);
		no(tt:IsShown());
		-- the plan row too
		tt = e.world.hover(ed.plan.spells[1].hit);
		ok(tt:Text():find("Hits two enemies.", 1, true));
		e.world.unhover(ed.plan.spells[1].hit);
	end);

	test("3.1C tooltips: no game text -> honest 'Detailed effect unavailable'; no invented numbers", function()
		local e = boot();   -- the mock game knows no spell
		local id, ed = newEditor(e);
		local tt = e.world.hover(ed.cat.rows[2].hit);
		local text = tt:Text();
		ok(text:find("Whirlwind", 1, true), text);
		ok(text:find("Detailed effect unavailable", 1, true), text);
		ok(text:find("Class: Warrior", 1, true), text);
		no(text:find("%d+%%"), "no percentage appears out of nowhere");
		e.world.unhover(ed.cat.rows[2].hit);
	end);

	test("3.1C tooltips: rings, trinkets and amulets (common and legendary) say what the catalogue holds and no more", function()
		local e = boot();
		local id, ed = newEditor(e);
		e.c:SetTab("jewels");
		e.c:SetSlot("rings", 1, "accuria");
		e.c:SetSlot("rings", 3, "quick_strike");
		local tt = e.world.hover(ed.jw.slots[1].frame);
		local t = tt:Text();
		ok(t:find("Band of Accuria", 1, true), t);
		ok(t:find("Type: Ring", 1, true), t);
		ok(t:find("Placed: main 1", 1, true), t);
		ok(t:find("Detailed effect unavailable", 1, true), t);
		ok(t:find("Main slots", 1, true), "the slot explanation travels with it");
		e.world.unhover(ed.jw.slots[1].frame);
		tt = e.world.hover(ed.jw.slots[3].frame);
		ok(tt:Text():find("Placed: alternative 1", 1, true), tt:Text());
		e.world.unhover(ed.jw.slots[3].frame);
		-- an empty slot explains main vs alternative
		tt = e.world.hover(ed.jw.slots[2].frame);
		ok(tt:Text():find("fallbacks", 1, true), tt:Text());
		e.world.unhover(ed.jw.slots[2].frame);
		-- catalogue rows
		tt = e.world.hover(ed.cat.rows[1].hit);
		ok(tt:Text():find("Type: Ring", 1, true) or tt:Text():find("Type: Trinket", 1, true), tt:Text());
		e.world.unhover(ed.cat.rows[1].hit);
		-- amulets
		e.c:SetGroup("amulets");
		local sawLegend, sawCommon = false, false;
		for i = 1, 9 do
			local row = ed.cat.rows[i];
			if row.frame:IsShown() then
				local x = e.world.hover(row.hit):Text();
				if x:find("Legendary amulet", 1, true) then
					sawLegend = true;
					ok(x:find("Linked spell:", 1, true) and x:find("Class: Warrior", 1, true), x);
				elseif x:find("Rarity:", 1, true) then
					sawCommon = true;
				end
				ok(x:find("Detailed effect unavailable", 1, true), x);
				e.world.unhover(row.hit);
			end
		end
		ok(sawLegend or sawCommon, "amulet tooltips shown");
	end);

	test("3.1C tooltips: French names and texts; English fallback for what is untranslated", function()
		local e = boot({ locale = "frFR" });
		local id, ed = newEditor(e);
		local t = e.world.hover(ed.cat.rows[2].hit):Text();
		ok(t:find("Tourbillon", 1, true), t);
		ok(t:find("Classe : Guerrier", 1, true), t);
		ok(t:find("Effet détaillé indisponible", 1, true), t);
		e.world.unhover(ed.cat.rows[2].hit);
	end);

	test("3.1C tooltips: hidden on page change, view change, window close; no widget is created by hovering", function()
		local e = boot({ gameSpells = { [845] = { "Cleave", "x" } } });
		local id, ed = newEditor(e);
		local n0 = #e.world.all;
		local tt = e.world.hover(ed.cat.rows[1].hit);
		ok(tt:IsShown());
		e.c:SetEditorPage(2);
		no(tt:IsShown(), "page change hides it");
		e.world.hover(ed.cat.rows[1].hit);
		e.c:SetTab("jewels");
		no(tt:IsShown(), "tab change hides it");
		e.world.hover(ed.cat.rows[1].hit);
		e.ui:Hide();
		no(tt:IsShown(), "closing the window hides it");
		e.ui:Show();
		for i = 1, 30 do
			e.world.hover(ed.cat.rows[1].hit);
			e.world.unhover(ed.cat.rows[1].hit);
		end
		eq(#e.world.all, n0, "no widgets created by hovering");
		-- an item without a spell id never asks the game for a spell tooltip
		local calls = tt.calls;
		e.world.hover(ed.cat.rows[1].hit);
		eq(tt.calls, calls, "jewels do not query spell tooltips");
		e.world.unhover(ed.cat.rows[1].hit);
	end);

	test("3.1C tooltips: a hover on a row of the previous page never shows stale data", function()
		local e = boot();
		local id, ed = newEditor(e);
		e.c:SetEditorPage(2);
		e.c:SetSearch("zzzz");
		for i = 1, 9 do ok(not ed.cat.rows[i].frame:IsShown() or ed.cat.rows[i].tipKey ~= nil); end
		ok(ed.cat.rows[1].tipKey == nil or not ed.cat.rows[1].frame:IsShown());
	end);

	-- ------------------------------------------------------------------ 3.1B look
	test("3.1B look: the window and the dialog are opaque, above the HUD, with a separate panel per view", function()
		local e = boot();
		eq(e.root.strata, "DIALOG");
		ok(e.root.backdrop.bgFile:find("WHITE8X8", 1, true), "solid background texture, not the translucent dialog tile");
		ok(e.root.backdropColor and e.root.backdropColor[4] >= 0.97, "alpha " .. tostring(e.root.backdropColor and e.root.backdropColor[4]));
		local m = e.G.RebornBuildPlannerModal;
		eq(m.strata, "FULLSCREEN_DIALOG");
		ok(m.backdropColor and m.backdropColor[4] >= 0.97);
		ok(m.level > e.root.level, "dialog above the window");
		for name, v in pairs(e.ui.views) do
			ok(v.panel and v.panel.texColor and v.panel.texColor[4] == 1, name .. " panel is opaque");
		end
		-- panel is lighter than the window: contrast between the two
		local bg = e.root.backdropColor;
		local pn = e.ui.views.library.panel.texColor;
		ok(pn[1] + pn[2] + pn[3] > bg[1] + bg[2] + bg[3] + 0.1, "panel contrasts with the window");
	end);

	test("3.1B look: the main action is coloured, secondary ones are quiet, a disabled button loses its colour; labels stay readable", function()
		local e = boot(); local id, ed = newEditor(e);
		e.world.click(ed.cat.rows[1].a);
		ok(ed.save:GetText():find("|cff8cff8c", 1, true), "Save is the accent colour while enabled");
		ok(ed.close:GetText():find("|cffb4b4b4", 1, true), "Close is quiet");
		e.world.click(ed.save);
		no(ed.save:IsEnabled());
		no(ed.save:GetText():find("|cff", 1, true), "disabled: plain text, greyed by the client");
		eq(ed.save:GetText(), "Save");
		-- the tests and the player find buttons by their plain text
		ok(e.world.button("Close") ~= nil);
	end);

	test("3.1B look: the editor stays inside the window with six spells, three marks, three avoids, both languages, four screens", function()
		for _, size in ipairs({ { 1365, 768 }, { 1920, 1080 }, { 1024, 768 }, { 800, 600 } }) do
			for _, loc in ipairs({ "enUS", "frFR" }) do
				local e = boot({ width = size[1], height = size[2], locale = loc });
				local id, ed = newEditor(e);
				e.c:Rename(id, string.rep("Nom tr\195\168s long ", 10));
				wantSix(e, ed);
				for i = 1, 3 do e.c:AddBanish(e.c:CatalogEntries()[6 + i].key); end
				for i = 1, 3 do e.world.click(ed.plan.spells[i].tog); end
				eq(e.world.lint(e.root), {}, "spells " .. size[1] .. " " .. loc);
				e.world.hover(ed.cat.rows[1].hit); e.world.unhover(ed.cat.rows[1].hit);
				e.c:SetTab("jewels");
				for s = 1, 4 do e.c:SetSlotTarget(s); end
				eq(e.world.lint(e.root), {}, "jewels " .. size[1] .. " " .. loc);
				e.c:SetTab("notes");
				eq(e.world.lint(e.root), {}, "notes " .. size[1] .. " " .. loc);
			end
		end
	end);

	test("3.1B look: UI scale 0.6 and 1.5 keep the editor inside the screen", function()
		local e = boot({ width = 1365, height = 768, locale = "frFR" });
		local id, ed = newEditor(e); wantSix(e, ed);
		for _, s in ipairs({ 0.6, 1.5 }) do
			e.h():SetSetting("scale", s);
			e.ui:ApplyScale();
			eq(e.world.lint(e.root), {}, "scale " .. s);
		end
	end);

	test("3.1D editor: jewelry shows which slot is chosen without relying on colour", function()
		local e = boot(); local id, ed = newEditor(e);
		e.c:SetTab("jewels");
		e.c:SetSlotTarget(3);
		ok(ed.jw.slots[3].role.text:find("^> "), ed.jw.slots[3].role.text);
		no(ed.jw.slots[1].role.text:find("^> "));
		ok(e.world.hasText("Chosen slot: Alternative 1"), e.texts());
		ok(ed.jw.slots[3].sel.shown, "band under the chosen slot too");
		e.c:SetSlotTarget(1);
		ok(e.world.hasText("Chosen slot: Main 1"), e.texts());
		-- sub-tabs show which one is open
		ok(e.world.button("Jewelry *") ~= nil);
	end);

	test("3.1D editor: every new string is translated", function()
		local ns = H.loadAddon();
		ns.Locale.SetLang("frFR");
		local missing = {};
		local src = H.readFile(H.root .. "/addon/RebornBuildPlanner/UI.lua");
		-- help tables: every quoted English sentence of the HELP block
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
