-- Lot 3.3: left library / centre editor + bottom details / right equipment browser; scrolling instead of paging;
-- flat visual style. Widget MOCK: nothing here proves rendering in the Reborn client.
return function(H)
	local eq, ok, no, test = H.eq, H.ok, H.no, H.test;
	local Stub = dofile(H.root .. "/tests/lua/wowstub.lua");

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
	local function rect(e, f) return e.world.rectOf(f); end

	test("3.3 layout: library left, editor centre, equipment browser RIGHT, details BELOW the editor", function()
		local e = boot({ width = 1920, height = 1080 });
		local id, ed = newEditor(e);
		local L, C, R = rect(e, e.ui.leftPanel), rect(e, e.ui.centre), rect(e, e.ui.rightPanel);
		ok(L[3] <= C[1] and C[3] <= R[1], "left < centre < right, no overlap");
		local rows = e.ui.bs.rows[1];
		local rr = rect(e, rows);
		ok(rr[1] >= R[1] and rr[3] <= R[3], "browser rows live in the right column");
		ok(rect(e, e.ui.bs.kinds.rings)[1] >= R[1], "category buttons in the right column");
		-- details are in the centre, below the equipment slots and the spells
		local det = rect(e, e.ui.det.head);
		local lastCell = rect(e, ed.groups.amulets.cells[1]);
		local lastSpell = rect(e, ed.spells[6].frame);
		ok(det[4] <= lastCell[2] + 0.5, "details start below the last equipment row");
		ok(det[4] <= lastSpell[2] + 0.5);
		ok(det[1] >= C[1] and det[3] <= C[3], "details are in the centre column");
		-- the old inspector column and the catalogue pagination are gone
		no(e.ui.ins, "no separate inspector column");
		no(e.ui.lib.pager, "library does not page");
		no(e.ui.bs.pager, "browser does not page");
		eq(e.world.lint(e.root), {});
	end);

	test("3.3 style: flat buttons (no red template), brass headers, row bands, opaque panels", function()
		local e = boot();
		newEditor(e);
		local n = 0;
		for _, f in ipairs(e.world.all) do
			if f.kind == "Button" then
				n = n + 1;
				no(f.template == "UIPanelButtonTemplate" or f.template == "UIPanelCloseButton", "template button " .. tostring(f.name or ""));
			end
		end
		ok(n > 50);
		ok(e.ui.ed.save.backdrop.bgFile:find("WHITE8X8", 1, true), "flat backdrop");
		for _, p in ipairs({ e.ui.leftPanel, e.ui.centre, e.ui.rightPanel }) do ok(p.backdropColor[4] == 1); end
		-- disabled buttons are visibly different from enabled ones
		local on, off = e.ui.ed.fav, e.ui.ed.save;     -- Favourite is enabled, Save has nothing to save
		no(on:IsEnabled() == off:IsEnabled() and on.backdropColor[1] == off.backdropColor[1] and on.backdropColor[2] == off.backdropColor[2]);
	end);

	test("3.3 flow: slot -> browser filters itself -> select -> details -> place / replace / empty", function()
		local e = boot({ locale = "enUS" });
		local id, ed = newEditor(e);
		-- 1. click the empty Trinket Alt. 1 slot
		e.world.click(ed.groups.trinkets.cells[3]);
		eq(e.c:Editor().cat, "trinkets", "browser follows the slot's kind");
		eq(e.c:Editor().slot, 3);
		ok(e.world.hasText("Target: Trinkets - Alternative 1 (empty)"), e.texts());
		for _, en in ipairs(e.c:CatalogEntries()) do eq(e.ns.catalog:Get("jewel", en.key).slot, "trinket"); end
		-- 2. select a piece: details below, Place enabled, nothing placed yet
		e.world.click(e.ui.bs.rows[2]);
		local key = e.c:CatalogEntries()[2].key;
		eq(e.c.state.inspect.key, key);
		eq(e.ui.det.title.text, e.ns.catalog:Get("jewel", key).name);
		ok(e.ui.det.body.text:find("Type: Trinket", 1, true), e.ui.det.body.text);
		eq(e.c:Editor().draft.phases[1].trinkets[3], "");
		ok(e.ui.det.act1:IsEnabled());
		ok(e.ui.det.act1.text:find("Place here", 1, true), e.ui.det.act1.text);
		-- 3. place
		e.world.click(e.ui.det.act1);
		eq(e.c:Editor().draft.phases[1].trinkets[3], key);
		eq(e.c:Editor().draft.phases[1].trinkets[1], "", "no other slot touched");
		ok(e.ui.ed.groups.trinkets.cells[3].name.text:find(e.ns.catalog:Get("jewel", key).name:sub(1, 6), 1, true));
		-- 4. the browser marks it as in the slot, and Place becomes 'Empty this slot'
		ok(e.ui.bs.rows[2].tag.text == "In slot", e.ui.bs.rows[2].tag.text);
		ok(e.ui.det.act1.text:find("Empty this slot", 1, true), e.ui.det.act1.text);
		-- 5. replace directly: another piece, same slot, no manual emptying
		e.world.click(e.ui.bs.rows[3]);
		local k3 = e.c:CatalogEntries()[3].key;
		e.world.click(e.ui.det.act1);
		eq(e.c:Editor().draft.phases[1].trinkets[3], k3, "replaced in place");
		-- 6. a piece placed in ANOTHER slot cannot be placed twice
		e.world.click(ed.groups.trinkets.cells[1]);
		e.world.click(e.ui.bs.rows[3]);
		no(e.ui.det.act1:IsEnabled());
		ok(e.ui.det.act1.text:find("Already placed", 1, true));
		-- 7. clicking the equipped cell shows its details; empty it from there
		e.world.click(ed.groups.trinkets.cells[3]);
		eq(e.ui.det.title.text, e.ns.catalog:Get("jewel", k3).name);
		ok(e.ui.det.act1.text:find("Empty this slot", 1, true));
		e.world.click(e.ui.det.act1);
		eq(e.c:Editor().draft.phases[1].trinkets[3], "");
		ok(e.c:EditorReport().clean);
	end);

	test("3.3 flow: double-click on a browser row places / adds; spells through the same panel", function()
		local e = boot();
		local id, ed = newEditor(e);
		e.world.click(ed.groups.rings.cells[2]);
		e.ui.bs.rows[1].scripts.OnDoubleClick(e.ui.bs.rows[1]);
		ok(e.c:Editor().draft.phases[1].rings[2] ~= "", "double click placed the ring in the chosen slot");
		-- spells: select -> Add -> Avoid is the other action -> Remove
		e.world.click(e.ui.bs.kinds.spells);
		e.world.click(e.ui.bs.rows[1]);
		ok(e.ui.det.act1.text:find("Add to my spells", 1, true));
		e.world.click(e.ui.det.act1);
		eq(#e.c:Editor().draft.phases[1].spells, 1);
		ok(e.ui.det.act1.text:find("Remove from my spells", 1, true));
		ok(e.ui.bs.rows[1].tag.text == "Wanted");
		no(e.ui.det.act2:IsEnabled(), "a wanted spell cannot be avoided");
		e.world.click(e.ui.bs.rows[2]);
		e.world.click(e.ui.det.act2);
		eq(#e.c:Editor().draft.phases[1].banish, 1);
		ok(e.ui.det.act2.text:find("Stop avoiding", 1, true));
		no(e.ui.det.act1:IsEnabled(), "an avoided spell cannot be wanted");
		e.world.click(e.ui.det.act2);
		eq(#e.c:Editor().draft.phases[1].banish, 0);
		-- clicking a spell of the plan shows it in the details too
		e.world.click(ed.spells[1].hit);
		ok(e.ui.det.act1.text:find("Remove from my spells", 1, true));
		e.world.click(e.ui.det.act1);
		eq(#e.c:Editor().draft.phases[1].spells, 0);
	end);

	test("3.3 lists scroll: wheel and slider move the browser and the library; clamped; no page widgets", function()
		local e = boot();
		local id, ed = newEditor(e);
		local all = #e.c:CatalogEntries();
		local _, off, max = e.c:CatalogView();
		eq(off, 0);
		eq(max, math.max(0, all - e.ns.Controller.CATALOG_ROWS));
		ok(max > 0, "more spells than rows");
		local first = e.ui.bs.rows[1].name.text;
		e.ui.bs.area.hold.scripts.OnMouseWheel(e.ui.bs.area.hold, -1);
		eq(e.c:Editor().offset, math.min(3, max), "wheel down scrolls up to three rows");
		ok(e.ui.bs.rows[1].name.text ~= first);
		e.ui.bs.area.hold.scripts.OnMouseWheel(e.ui.bs.area.hold, 1);
		eq(e.c:Editor().offset, 0);
		e.ui.bs.area.hold.scripts.OnMouseWheel(e.ui.bs.area.hold, 1);
		eq(e.c:Editor().offset, 0, "clamped at the top");
		-- the slider drives the offset and follows it
		e.ui.bs.area.slider.scripts.OnValueChanged(e.ui.bs.area.slider, max);
		eq(e.c:Editor().offset, max);
		eq(e.ui.bs.area.slider:GetValue(), max);
		e.c:ScrollCatalog(1000);
		eq(e.c:Editor().offset, max);
		-- searching and switching kind restart at the top; the list shrinks and the slider hides when it all fits
		e.world.type(e.ui.bs.search, "zzzz");
		eq(e.c:Editor().offset, 0);
		no(e.ui.bs.rows[1]:IsShown());
		ok(e.world.hasText("Nothing matches this search."), e.texts());
		e.world.type(e.ui.bs.search, "");
		e.c:SetCatalogOffset(5);
		e.world.click(e.ui.bs.kinds.rings);
		eq(e.c:Editor().offset, 0);
		-- library: 25 builds scroll too
		for i = 1, 25 do e.c:Create("L" .. i, "mage"); end
		local _, _, lmax = e.c:LibView();
		ok(lmax > 0);
		e.ui.lib.area.hold.scripts.OnMouseWheel(e.ui.lib.area.hold, -1);
		eq(e.c.state.libOffset, 3);
		eq(e.world.lint(e.root), {});
	end);

	test("3.3 right-hand search: by name, French name, empty result, kind kept", function()
		local e = boot({ locale = "frFR" });
		local id, ed = newEditor(e);
		e.world.type(e.ui.bs.search, "tourb");
		eq(#e.c:CatalogEntries(), 1);
		eq(e.ui.bs.rows[1].name.text, "Tourbillon");
		e.world.click(e.ui.bs.kinds.rings);
		eq(e.c:Editor().search, "tourb", "search text is kept when the kind changes");
		eq(#e.c:CatalogEntries(), 0);
		e.world.type(e.ui.bs.search, "accuria");
		ok(#e.c:CatalogEntries() >= 1);
		e.world.type(e.ui.bs.search, "");
	end);

	test("3.3 details: honest about missing data, same text as before, nothing invented", function()
		local e = boot({ gameSpells = { [845] = { "Cleave", "Hits two enemies." } } });
		local id, ed = newEditor(e);
		ok(e.world.hasText("Select a spell or a piece"), e.texts());
		e.world.click(e.ui.bs.rows[1]);
		ok(e.ui.det.body.text:find("Hits two enemies.", 1, true), e.ui.det.body.text);
		ok(e.ui.det.source.text:find("game's own spell text", 1, true));
		eq(e.ui.det.type.text, "Spell | Warrior");
		e.world.click(e.ui.bs.rows[2]);
		ok(e.ui.det.body.text:find("Detailed effect unavailable", 1, true));
		ok(e.ui.det.source.text:find("Reborn catalogue", 1, true));
		e.world.click(e.ui.bs.kinds.rings);
		e.world.click(e.ui.bs.rows[1]);
		ok(e.ui.det.body.text:find("Detailed effect unavailable", 1, true));
		no(e.ui.det.body.text:find("%d+%%"));
		-- the advanced block takes the detail area and gives it back
		e.c:ToggleAdvanced();
		no(e.ui.det.title:IsVisible()); ok(e.ui.ed.nt.notes.scroll:IsVisible());
		e.c:ToggleAdvanced();
		ok(e.ui.det.title:IsVisible()); no(e.ui.ed.nt.notes.scroll:IsVisible());
	end);

	test("3.3 browser and details survive build switching: the selection and the target follow the open build", function()
		local e = boot();
		local a, b = e.c:Create("A", "warrior"), e.c:Create("B", "mage");
		e.ui:OpenEditor(a);
		e.world.click(e.ui.ed.groups.amulets.cells[1]);
		e.world.click(e.ui.bs.rows[1]);
		ok(e.c.state.inspect ~= nil);
		e.ui:OpenEditor(b);
		eq(e.c.state.inspect, nil, "the selection is cleared when another build opens");
		eq(e.c:Editor().cat, "spells");
		for _, en in ipairs(e.c:CatalogEntries()) do eq(e.ns.catalog:Get("spell", en.key).class, "mage"); end
		e.c:CloseEditor();
		ok(e.world.hasText("Open a build to browse"), e.texts());
		for _, r in ipairs(e.ui.bs.rows) do no(r:IsShown()); end
	end);

	test("3.3 layout lint: five screens, both languages, three scales, fully filled build", function()
		for _, size in ipairs({ { 1920, 1080 }, { 1365, 768 }, { 1280, 720 }, { 1024, 768 }, { 800, 600 } }) do
			for _, loc in ipairs({ "enUS", "frFR" }) do
				local e = boot({ width = size[1], height = size[2], locale = loc });
				local id, ed = newEditor(e);
				e.c:Rename(id, string.rep("Nom tr\195\168s long ", 10));
				local keys = e.ns.catalog:SpellsOfClass("warrior");
				for i = 1, 6 do e.c:AddSpell(keys[i]); end
				for i = 1, 3 do e.c:ToggleBanishAfter(keys[i]); end
				for _, g in ipairs({ "rings", "trinkets", "amulets" }) do
					e.c:SetCatalog(g);
					for s = 1, #e.c:Editor().draft.phases[1][g] do e.c:SelectSlot(g, s); e.c:SetSlot(g, s, e.c:CatalogEntries()[s].key); end
				end
				e.c:SetCatalog("amulets"); e.c:Inspect("amulet", e.c:CatalogEntries()[1].key);
				for _, sc in ipairs({ 0.6, 1, 1.5 }) do
					e.h():SetSetting("scale", sc);
					e.ui:ApplyScale();
					eq(e.world.lint(e.root), {}, size[1] .. "x" .. size[2] .. " " .. loc .. " scale " .. sc);
				end
				e.c:Inspect("spell", keys[1]);
				e.c:ToggleAdvanced();
				eq(e.world.lint(e.root), {}, "advanced " .. size[1] .. " " .. loc);
			end
		end
	end);

	test("3.3 non-regression: favourites, recents, banishAfter, export loss, read-only, no widget growth", function()
		local e = boot();
		local id, ed = newEditor(e);
		local n0 = #e.world.all;
		local keys = e.ns.catalog:SpellsOfClass("warrior");
		for i = 1, 6 do e.c:AddSpell(keys[i]); end
		for i = 1, 3 do e.world.click(ed.spells[i].tog); end
		eq(#e.c:Editor().draft.phases[1].banishAfter, 3);
		e.world.click(e.ui.nav.export);
		ok(e.c.state.export.report.intentLosses >= 3, "banishAfter loss still announced");
		e.c:SetView("editor");
		e.world.click(ed.fav);
		ok(e.h():Meta(id).fav);
		for i = 1, 30 do e.c:ScrollCatalog(3); e.c:ScrollCatalog(-3); e.world.hover(e.ui.bs.rows[1]); e.world.unhover(e.ui.bs.rows[1]); end
		eq(#e.world.all, n0, "scrolling and hovering create no widget");
		local ro = boot({ preset = nil });
		ro.h().readOnly = true; ro.h().status = "REPAIR_REFUSED"; ro.c:Notify();
		for _, b in ipairs({ ro.ui.lib.create, ro.ui.lib.dup, ro.ui.lib.delete }) do no(b:IsEnabled()); end
		for _, f in ipairs(e.world.all) do no(f.scripts and f.scripts.OnUpdate, "no OnUpdate"); end
	end);
end
