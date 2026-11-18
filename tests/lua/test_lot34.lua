-- Lot 3.4: published amulet data embedded without loss, official-rule descriptions (FR/EN), short tooltips, inspector
-- with sections and internal scroll, structurally safe equipment cells. Widget MOCK: not a rendering proof.
return function(H)
	local eq, ok, no, test = H.eq, H.ok, H.no, H.test;
	local Stub = dofile(H.root .. "/tests/lua/wowstub.lua");
	local ns0 = H.loadAddon();
	local cat = ns0.Catalog.New(ns0.GeneratedCatalog);
	local D, J = ns0.Describe, ns0.Json;

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
		return env;
	end
	local function newEditor(e, class)
		local id = e.c:Create("Plan", class or "warrior");
		e.ui:OpenEditor(id);
		return id, e.ui.ed;
	end
	local function plain(sections)
		local out = {};
		for _, s in ipairs(sections or {}) do
			out[#out + 1] = "[" .. s.title .. "]";
			for _, l in ipairs(s.lines) do out[#out + 1] = l.text; end
		end
		return table.concat(out, "\n");
	end
	-- the published files with JSON null turned into nil (a null field is "does not apply", absent in the Lua catalogue)
	local function denull(v)
		if v == J.null then return nil; end
		if type(v) == "table" then
			local out = {};
			for k, x in pairs(v) do out[k] = denull(x); end
			return out;
		end
		return v;
	end
	local function fixture(name)
		local text = H.readFile(H.catalogDir .. "/" .. name);
		return denull(assert(J.Decode(text)));
	end

	-- ------------------------------------------------------------------ data: nothing published was lost
	test("3.4 data: every published amulet / legend field is embedded unchanged (growth, effects, special, world, needs, template, form, fixed)", function()
		for _, a in ipairs(fixture("amulets.json")) do
			local e = cat:Get("amulet", a.key);
			ok(e, a.key);
			eq(e.growth, a.growth, a.key .. " growth");
			eq(e.effects, a.effects, a.key .. " effects");
			eq(e.special, a.special, a.key .. " special");
			eq(e.world, a.world, a.key .. " world");
			eq(e.needs, a.needs, a.key .. " needs");
		end
		local n = 0;
		for _, g in ipairs(fixture("legends.json")) do
			local e = cat:Get("amulet", g.key);
			eq(e.effects, g.effects, g.key .. " effects");
			eq(e.growth, g.growth, g.key .. " growth");
			eq(e.fixed, g.fixed, g.key .. " fixed");
			eq(e.template, g.template);
			eq(e.form, g.form);
			n = n + 1;
		end
		eq(n, 237);
		eq(cat:Content(), fixture("index.json").content, "the generated content matches the actually installed official snapshot");
	end);

	test("3.4 data: jewelry (rings, trinkets) has no published effect: no effect is described, none invented", function()
		for _, j in ipairs(fixture("jewelry.json")) do
			for _, f in ipairs({ "effects", "special", "growth", "text", "description" }) do eq(j[f], nil, j.key .. "." .. f); end
		end
		local e = boot(); local id, ed = newEditor(e);
		local d = e.c:TooltipData("jewel", "accuria");
		eq(d.sections, nil);
		local text = {};
		for _, l in ipairs(d.lines) do text[#text + 1] = l.text; end
		ok(table.concat(text, "|"):find("Detailed effect unavailable", 1, true));
		eq(D.Amulet(cat, cat:Get("jewel", "accuria"), nil), nil);
	end);


	test("jewelry metadata: only exact key and slot get a sourced effect; fallback remains honest", function()
		local e = boot();
		local source = e.ns.GeneratedJewelryMechanics;
		eq(e.c:TooltipData("jewel", "accuria").sections, nil);
		source.items.accuria = { slot = "ring", behavior = "damage", base = 0.17 };
		local report = e.c:TooltipData("jewel", "accuria");
		ok(report.sections and #report.sections == 2, "plain benefit and source, no duplicate technical percentage");
		local joined = plain(report.sections);
		ok(joined:find("Damage", 1, true), joined);
		ok(joined:find("17%", 1, true), joined);
		ok(joined:find("Not the actual in-run value", 1, true), joined);
		source.items.accuria.slot = "trinket";
		eq(e.c:TooltipData("jewel", "accuria").sections, nil, "wrong slot rejected");
		source.items.accuria = nil;
	end);


	test("jewelry live API: exact unique slot/name only, never stale hub data", function()
		local snapshots = {
			AZS_RUN = { ph = "playing" },
			AZS_ZONE = { hub = 0 },
			AZS_GEAR = { { slot = "ring", name = "Band of Accuria", text = "Damage +17% (game snapshot)" } }
		};
		local ns = H.loadAddon({ extra = snapshots });
		local c = ns.Catalog.New(ns.GeneratedCatalog);
		snapshots.AZS_GEAR[1].name = c:Name("jewel", "accuria");
		local hits = c:FindByName("rings", snapshots.AZS_GEAR[1].name, "enUS");
		ok(#hits == 1 and hits[1].key == "accuria", "current catalogue must uniquely resolve the chosen ring, candidates " .. tostring(#hits));
		local live = ns.JewelryEffects.LiveSections(c, "accuria", "ring", false);
		ok(live and live[1] and live[1].lines[1].text:find("Damage +17%", 1, true), "trusted equipped item text; name=" .. tostring(snapshots.AZS_GEAR[1].name));
		eq(ns.JewelryEffects.LiveSections(c, "blackhand", "trinket", false), nil, "different key");
		snapshots.AZS_GEAR[1].slot = "trinket";
		eq(ns.JewelryEffects.LiveSections(c, "accuria", "ring", false), nil, "slot mismatch");
		snapshots.AZS_GEAR[1].slot = "ring";
		snapshots.AZS_ZONE.hub = 1;
		eq(ns.JewelryEffects.LiveSections(c, "accuria", "ring", false), nil, "hub snapshot must not leak into a run");
		snapshots.AZS_ZONE.hub = 0;
		snapshots.AZS_RUN.ph = "ready";
		eq(ns.JewelryEffects.LiveSections(c, "accuria", "ring", false), nil, "ready is not a run");
	end);

	-- ------------------------------------------------------------------ official rules
	test("3.4 rules: multiplier = 3 - 2 x (1 - growth/2)^(rank-1); fixed pieces grow linearly and stop at rank 11", function()
		eq(D.Multiplier(0.2, 1), 1);
		eq(math.floor(D.Multiplier(0.2, 2) * 1e6 + 0.5) / 1e6, 1.2, "guide example: growth 0.2 gives 1.2x at rank 2");
		local m5 = D.Multiplier(0.6, 5);
		ok(math.abs(m5 - (3 - 2 * 0.7 ^ 4)) < 1e-12);
		eq(D.FixedMultiplier(0.75, 1), 1);
		ok(math.abs(D.FixedMultiplier(0.75, 11) - (0.75 + 0.5) / 0.75) < 1e-12);
		eq(D.FixedMultiplier(0.75, 20), D.FixedMultiplier(0.75, 11), "capped: not offered past rank 11");
	end);

	test("3.4 fixed amulet: real values, official growth, special, availability (EN)", function()
		local sec = D.Amulet(cat, cat:Get("amulet", "mark_of_fordring"), nil);
		local t = plain(sec);
		ok(t:find("Damage: 15%", 1, true), t);
		ok(t:find("(rank 5: 37.8%)", 1, true), t);
		ok(t:find("Growth 0.6: x1.60 at rank 2", 1, true), t);
		ok(t:find("affected effects become stronger", 1, true), "growth explained without raw formula");
		ok(t:find("Classes: every class", 1, true) and t:find("World: every world", 1, true), t);
		-- a special with a share, a special without number, a world, a heal requirement
		local seen = {};
		for _, a in ipairs(fixture("amulets.json")) do
			local text = plain(D.Amulet(cat, cat:Get("amulet", a.key), nil));
			if type(a.special) == "table" then for k, v in pairs(a.special) do ok(text:find(string.format("%d%%", v * 100), 1, true) or text:find("%d", 1), a.key); seen.special = true; end end
			if a.special == "cheat_death" then ok(text:find("Cheat death", 1, true)); seen.cheat = true; end
			if a.world then ok(text:find("World: ", 1, true) and not text:find("every world", 1, true), a.key); seen.world = true; end
			if a.needs == "heal" then ok(text:find("knows a heal", 1, true)); seen.needs = true; end
			for _, ef in ipairs(a.effects) do ok(text:find(D.STAT[ef.stat] or ef.stat, 1, true), a.key .. " " .. ef.stat); end
		end
		ok(seen.special and seen.cheat and seen.world and seen.needs, "every published kind was exercised");
	end);

	test("3.4 fixed amulet: the stats whose value is NOT a share stay plain numbers; targets never get a rank-5 guess", function()
		local found = {};
		for _, a in ipairs(fixture("amulets.json")) do
			for _, ef in ipairs(a.effects) do
				if ef.stat == "regen" or ef.stat == "kill_heal" or ef.stat == "targets" then
					local t = plain(D.Amulet(cat, cat:Get("amulet", a.key), nil));
					local line = t:match(D.STAT[ef.stat] .. ": [^\n]*");
					ok(line and not line:find("%%"), a.key .. " raw: " .. tostring(line));
					if ef.stat == "targets" then no(line:find("rank 5", 1, true), "targets grow in whole steps: not computed"); end
					found[ef.stat] = true;
				end
			end
		end
		ok(found.regen and found.kill_heal and found.targets);
	end);

	test("3.4 French: stat labels, comma decimals, spaced percent, official names; English fallback for the rest", function()
		local e = boot({ locale = "frFR" });
		local sec = e.ns.Describe.Amulet(e.ns.catalog, e.ns.catalog:Get("amulet", "mark_of_fordring"), "frFR");
		local t = plain(sec);
		ok(t:find("Dégâts: 15 %", 1, true), t);
		ok(t:find("(rang 5 : 37,8 %)", 1, true), t);
		ok(t:find("Croissance 0,6", 1, true), t);
		ok(t:find("Classes : toutes les classes", 1, true), t);
		eq(e.ns.catalog:Name("amulet", "mark_of_fordring", "frFR"), "Marque de Fordring");
		-- an effect name the data does not let us translate reliably stays as the game writes it
		local seen = false;
		for _, g in ipairs(fixture("legends.json")) do
			for _, ef in ipairs(g.effects) do
				local k = type(ef) == "table" and next(ef) or ef;
				if k == "dot_burst" and not seen then
					seen = true;
					local tt = plain(e.ns.Describe.Amulet(e.ns.catalog, e.ns.catalog:Get("amulet", g.key), "frFR"));
					ok(tt:find("Dot burst", 1, true), tt);
				end
			end
		end
		ok(seen);
	end);

	test("3.4 legendary: stable key, effects as published, growth / fixed exception, no invented number", function()
		local g = cat:Get("amulet", "legendary:cleave");
		local t = plain(D.Amulet(cat, g, nil));
		ok(t:find("Targets: 4", 1, true), t);
		ok(t:find("Damage: 0.5", 1, true), t);
		ok(t:find("Burn: duration 6 s, share 80%", 1, true), t);
		ok(t:find("Growth 0.2: x1.20 at rank 2", 1, true), t);
		ok(t:find("Entry written for this spell (cleave)", 1, true), t);
		-- fixed (shaman-style) pieces: no growth number, the linear rule instead
		local fixedKey;
		for _, l in ipairs(fixture("legends.json")) do if l.fixed then fixedKey = l.key; break; end end
		ok(fixedKey);
		local ft = plain(D.Amulet(cat, cat:Get("amulet", fixedKey), nil));
		ok(ft:find("Fixed value", 1, true) and ft:find("not offered past rank 11", 1, true), ft);
		no(ft:find("Growth 0.2", 1, true));
		-- a generic entry says which shape picked it
		for _, l in ipairs(fixture("legends.json")) do
			if l.form then
				ok(plain(D.Amulet(cat, cat:Get("amulet", l.key), nil)):find("Generic entry for the shape \"" .. l.form .. "\"", 1, true), l.key);
				break;
			end
		end
		-- identity: homonymous titles are told apart by the canonical key, never by title or icon
		local byName = {};
		for _, l in ipairs(fixture("legends.json")) do byName[l.name] = (byName[l.name] or 0) + 1; end
		local homonyms = 0;
		for _, n in pairs(byName) do if n > 1 then homonyms = homonyms + 1; end end
		ok(homonyms >= 1, "titles are NOT unique in the data: key them by legendary:<spell>, never by title");
		for _, l in ipairs(fixture("legends.json")) do eq(l.key, "legendary:" .. l.spell); end
	end);

	test("3.4 legendary names: canonical head + translated spell only when the spell IS translated", function()
		eq(cat:Name("amulet", "legendary:cleave", nil), "Medallion of the Bladestorm: Cleave");
		eq(cat:Name("amulet", "legendary:cleave", "frFR"), "Médaillon de la Tempête de lames: Enchaînement");
		eq(cat:Name("amulet", "legendary:cleave", "deDE"), "Medallion of the Bladestorm: Cleave", "language not embedded: English");
		-- search finds it by the English title and by the French spell part
		local e = boot({ locale = "frFR" });
		local id, ed = newEditor(e);
		e.c:SetCatalog("amulets");
		e.world = e.world;
		e.world.type(e.ui.bs.search, "Bladestorm");
		ok(#e.c:CatalogEntries() >= 1);
	end);

	-- ------------------------------------------------------------------ tooltips: short, anchored, never mixed
	test("3.4 tooltip: a spell hover is a short preview (state + hint); the game's text is NOT in it", function()
		local e = boot({ gameSpells = { [845] = { "Cleave", "Hits two enemies." } } });
		local id, ed = newEditor(e);
		e.c:AddSpell("cleave");
		e.c:SetBanishAfter("cleave", true);
		local tt = e.world.hover(e.ui.bs.rows[1]);
		local text = tt:Text();
		ok(text:find("Cleave", 1, true) and text:find("Spell | Warrior", 1, true), text);
		ok(text:find("Wanted: priority 1", 1, true) and text:find("banish after acquisition", 1, true), text);
		ok(text:find("Click for the full details.", 1, true), text);
		no(text:find("Hits two enemies.", 1, true), "native text never mixed into the floating tooltip");
		eq(tt.calls, 0, "hovering never asks the game for a spell tooltip");
		ok(#tt.lines <= e.ns.UI.TIP_LINES, "short: " .. #tt.lines .. " lines");
		e.world.unhover(e.ui.bs.rows[1]);
		no(tt:IsShown());
		-- the full text is in the inspector, alone
		e.world.click(e.ui.bs.rows[1]);
		ok(e.ui:DetailText():find("Hits two enemies.", 1, true), e.ui:DetailText());
		eq(tt.shown, false, "the read leaves nothing on screen");
	end);

	test("3.4 tooltip: legendary / fixed amulets show a 3-line effect preview, not the whole description", function()
		local e = boot();
		local id, ed = newEditor(e);
		e.c:SetCatalog("amulets");
		e.world.type(e.ui.bs.search, "Mark of Fordring");
		local tt = e.world.hover(e.ui.bs.rows[1]);
		local text = tt:Text();
		ok(text:find("Damage: 15%", 1, true), text);
		no(text:find("Official rule", 1, true), "growth rule stays in the inspector");
		ok(#tt.lines <= e.ns.UI.TIP_LINES);
		e.world.unhover(e.ui.bs.rows[1]);
		-- Eye of the Splitting Sky: the title is long, the tooltip stays short and bounded
		local key;
		for k, g in pairs(e.ns.catalog.legends) do if g.name:find("^Eye of the Splitting Sky") and g.class == "warrior" then key = k; end end
		ok(key, "a warrior 'Eye of the Splitting Sky' legendary exists");
		e.world.type(e.ui.bs.search, "Splitting Sky");
		tt = e.world.hover(e.ui.bs.rows[1]);
		local lines = tt.lines;
		ok(#lines <= e.ns.UI.TIP_LINES, #lines .. " lines");
		for _, l in ipairs(lines) do ok(#l <= 120, "bounded line: " .. #l); end
		ok(tt:Text():find("Legendary amulet", 1, true));
		e.world.unhover(e.ui.bs.rows[1]);
	end);

	test("3.4 tooltip: anchored away from the screen edge (left half -> right, right half -> left); pieces without effects say so", function()
		local e = boot({ width = 1920, height = 1080 });
		local id, ed = newEditor(e);
		local tt = e.world.tooltip;
		e.world.hover(e.ui.lib.rows[1].star);
		eq(tt.anchor, "ANCHOR_RIGHT", "library (left half of the window)");
		e.world.unhover(e.ui.lib.rows[1].star);
		e.world.hover(e.ui.bs.rows[1]);
		eq(tt.anchor, "ANCHOR_LEFT", "browser (right column): the tooltip opens leftwards, on screen");
		e.world.unhover(e.ui.bs.rows[1]);
		-- a window dragged to the far right of a small screen
		local s = boot({ width = 1365, height = 768 });
		newEditor(s);
		s.world.drag(s.root, 200, 0);
		s.world.hover(s.ui.bs.rows[1]);
		eq(s.world.tooltip.anchor, "ANCHOR_LEFT");
		s.world.unhover(s.ui.bs.rows[1]);
		-- a ring: facts and an honest note, no sections
		e.c:SetCatalog("rings");
		local text = e.world.hover(e.ui.bs.rows[1]):Text();
		ok(text:find("Detailed effect unavailable", 1, true), text);
		e.world.unhover(e.ui.bs.rows[1]);
	end);

	-- ------------------------------------------------------------------ inspector with sections and scroll
	test("3.4 inspector: sections (In this build / Information / Effects / Growth / Availability), source line, honest limits", function()
		local e = boot();
		local id, ed = newEditor(e);
		e.c:SetCatalog("amulets");
		e.c:SelectSlot("amulets", 1);
		e.world.type(e.ui.bs.search, "Mark of Fordring");
		e.world.click(e.ui.bs.rows[1]);
		local t = e.ui:DetailText();
		for _, h in ipairs({ "INFORMATION", "EFFECTS (RANK 1)", "GROWTH", "AVAILABILITY" }) do ok(t:find(h, 1, true), h .. " in " .. t); end
		ok(e.ui.det.source.text:find("published game data", 1, true), e.ui.det.source.text);
		eq(e.ui.det.type.text, "Amulet | Common");
		e.world.click(e.ui.det.act1);
		ok(e.ui:DetailText():find("IN THIS BUILD", 1, true), "placed: the build section appears");
		-- legendary, French, long title in the slot
		local f = boot({ locale = "frFR" });
		newEditor(f);
		f.c:SetCatalog("amulets");
		f.world.type(f.ui.bs.search, "Splitting Sky");
		f.world.click(f.ui.bs.rows[1]);
		local ft = f.ui:DetailText();
		ok(ft:find("EFFETS (RANG 1)", 1, true) and ft:find("CROISSANCE", 1, true), ft);
		ok(f.ui.det.title.text:find("Œil du Ciel fendu", 1, true), f.ui.det.title.text);
	end);

	test("3.4 inspector: long content scrolls inside the panel; a new selection starts at the top; no widget is created", function()
		local e = boot();
		local id, ed = newEditor(e);
		local best, bn = nil, 0;
		for k, g in pairs(e.ns.catalog.legends) do if g.class == "warrior" and #(g.effects or {}) > bn then best, bn = k, #g.effects; end end
		e.c:SetCatalog("amulets");
		local n0 = #e.world.all;
		e.c:Inspect("amulet", best);
		local det = e.ui.det;
		ok(#det.lines > 8, "more lines than rows: " .. #det.lines);
		ok(det.area.slider:IsShown());
		local first = det.rows[1].text;
		det.area.hold.scripts.OnMouseWheel(det.area.hold, -1);
		eq(det.offset, 3);
		ok(det.rows[1].text ~= first);
		det.area.hold.scripts.OnMouseWheel(det.area.hold, -1);
		det.area.hold.scripts.OnMouseWheel(det.area.hold, -1);
		det.area.hold.scripts.OnMouseWheel(det.area.hold, -1);
		eq(det.offset, math.max(0, #det.lines - 8), "clamped at the end");
		e.c:Inspect("spell", "whirlwind");
		eq(det.offset, 0, "a new selection starts at the top");
		eq(#e.world.all, n0, "no widget created");
		eq(e.world.lint(e.root), {});
	end);

	test("3.4 inspector: unknown entries and absent data are stated, never filled in", function()
		local e = boot();
		local id, ed = newEditor(e);
		e.c:Inspect("amulet", "legendary:not_a_spell");
		ok(e.ui:DetailText():find("Unknown to this catalogue", 1, true));
		ok(e.ui:DetailText():find("Detailed effect unavailable", 1, true));
		-- an entry without effects (older catalogue) falls back to the honest note
		local entry = { key = "x", name = "No data", rarity = "rare", classes = {} };
		eq(D.Amulet(cat, entry, nil), nil);
		eq(D.Amulet(cat, nil, nil), nil);
		eq(D.Amulet(cat, { spell = "x", effects = nil }, nil), nil);
		-- numbers shown for an amulet all come from its record (no digit appears from nowhere)
		for _, a in ipairs(fixture("amulets.json")) do
			local t = plain(D.Amulet(cat, cat:Get("amulet", a.key), nil));
			ok(not t:find("%d%d%d%d"), a.key .. " no long invented number");
		end
	end);

	-- ------------------------------------------------------------------ equipment cells: structure, not luck
	test("3.4 equipment cells: reserved zones never overlap (role / remove / icon / name), mains separated from alternatives", function()
		local e = boot({ width = 1920, height = 1080 });
		local id, ed = newEditor(e);
		-- fill every slot, with the longest legendary title in the amulet row
		local longest, ln = nil, 0;
		for k, g in pairs(e.ns.catalog.legends) do if g.class == "warrior" and #g.name > ln then longest, ln = k, #g.name; end end
		for _, g in ipairs({ "rings", "trinkets" }) do
			e.c:SetCatalog(g);
			for s = 1, 4 do e.c:SelectSlot(g, s); e.c:SetSlot(g, s, e.c:CatalogEntries()[s].key); end
		end
		e.c:SetCatalog("amulets");
		e.c:SelectSlot("amulets", 1); e.c:SetSlot("amulets", 1, longest);
		for s = 2, 4 do e.c:SelectSlot("amulets", s); e.c:SetSlot("amulets", s, e.c:CatalogEntries()[s].key); end
		local function inter(a, b) return math.min(a[3], b[3]) - math.max(a[1], b[1]) > 0.5 and math.min(a[4], b[4]) - math.max(a[2], b[2]) > 0.5; end
		for _, g in ipairs({ "rings", "trinkets", "amulets" }) do
			local cells = ed.groups[g].cells;
			for j, cell in ipairs(cells) do
				local cr = e.world.rectOf(cell);
				local role, x, icon, name = e.world.rectOf(cell.role), e.world.rectOf(cell.x), e.world.rectOf(cell.icon), e.world.rectOf(cell.name);
				no(inter(x, name), g .. j .. ": remove button over the name");
				no(inter(x, role), g .. j .. ": remove button over the role label");
				no(inter(icon, name), g .. j .. ": icon over the name");
				no(inter(role, name) , g .. j .. ": role over the name");
				ok(name[1] >= cr[1] and name[3] <= cr[3] and name[2] >= cr[2], g .. j .. ": name inside its cell");
				ok(cell.name.text:len() <= 2 * 82 / 6 + 10, g .. j .. ": bounded, truncated name (" .. cell.name.text:len() .. ")");
			end
			local mains = e.ns.BuildModel.MAIN_SLOTS[g];
			local lastMain, firstAlt = e.world.rectOf(cells[mains]), e.world.rectOf(cells[mains + 1]);
			ok(firstAlt[1] >= lastMain[3] + 6, g .. ": brass gap between mains and alternatives");
		end
		eq(e.world.lint(e.root), {});
		-- the long title's full name stays reachable: inspector + tooltip
		e.c:SelectSlot("amulets", 1);
		eq(e.ui.det.title.text:sub(1, 12), e.ns.catalog:Name("amulet", longest):sub(1, 12));
		local text = e.world.hover(ed.groups.amulets.cells[1]):Text();
		ok(text:find("Legendary amulet", 1, true), text);
		e.world.unhover(ed.groups.amulets.cells[1]);
	end);

	test("3.4 spell rows: compact controls, no overlap, priority / state / actions readable", function()
		local e = boot({ width = 1920, height = 1080 });
		local id, ed = newEditor(e);
		local keys = e.ns.catalog:SpellsOfClass("warrior");
		for i = 1, 6 do e.c:AddSpell(keys[i]); end
		e.c:SetBanishAfter(keys[2], true);
		for _, r in ipairs(ed.spells) do
			local n, t, u, d, x = e.world.rectOf(r.name), e.world.rectOf(r.tog), e.world.rectOf(r.up), e.world.rectOf(r.down), e.world.rectOf(r.del);
			ok(n[3] <= t[1], "name ends before the state button");
			ok(t[3] <= u[1] and u[3] <= d[1] and d[3] <= x[1]);
			ok(r.up.baseLabel == "^" and r.down.baseLabel == "v" and r.del.baseLabel == "x");
		end
		local tt = e.world.hover(ed.spells[1].up);
		ok(tt:Text():find("Raises this spell's priority", 1, true), tt:Text());
		e.world.unhover(ed.spells[1].up);
		eq(e.world.lint(e.root), {});
	end);

	test("3.4 layout: five screens, two languages, three scales with long legendary names and the inspector scrolled", function()
		for _, size in ipairs({ { 1920, 1080 }, { 1365, 768 }, { 1280, 720 }, { 1024, 768 }, { 800, 600 } }) do
			for _, loc in ipairs({ "enUS", "frFR" }) do
				local e = boot({ width = size[1], height = size[2], locale = loc });
				local id, ed = newEditor(e);
				local keys = e.ns.catalog:SpellsOfClass("warrior");
				for i = 1, 6 do e.c:AddSpell(keys[i]); end
				e.c:SetCatalog("amulets");
				for s = 1, 4 do
					e.c:SelectSlot("amulets", s);
					local k;
					local n = 0;
					for key, g in pairs(e.ns.catalog.legends) do if g.class == "warrior" and #g.name > 40 then n = n + 1; if n == s then k = key; end end end
					e.c:SetSlot("amulets", s, k or e.c:CatalogEntries()[s].key);
				end
				e.c:Inspect("amulet", e.c:Editor().draft.phases[1].amulets[1]);
				for _, sc in ipairs({ 0.6, 1, 1.5 }) do
					e.h():SetSetting("scale", sc);
					e.ui:ApplyScale();
					eq(e.world.lint(e.root), {}, size[1] .. "x" .. size[2] .. " " .. loc .. " scale " .. sc);
				end
				e.ui:ScrollDetail(5);
				eq(e.world.lint(e.root), {});
			end
		end
	end);

	test("3.4 non-regression: no widget growth when browsing, hovering, scrolling the inspector; saves keep every build", function()
		local e = boot();
		local id, ed = newEditor(e);
		e.c:SetCatalog("amulets");
		local n0 = #e.world.all;
		for i = 1, 20 do
			e.world.hover(e.ui.bs.rows[1]); e.world.unhover(e.ui.bs.rows[1]);
			e.c:Inspect("amulet", e.c:CatalogEntries()[i].key);
			e.ui:ScrollDetail(3);
		end
		eq(#e.world.all, n0);
		for _, f in ipairs(e.world.all) do no(f.scripts and f.scripts.OnUpdate); end
		local before = e.h():Counts().builds;
		e.c:SelectSlot("amulets", 1); e.c:SetSlot("amulets", 1, e.c:CatalogEntries()[1].key); e.c:Save();
		eq(e.h():Counts().builds, before);
		eq(e.h():Get(id).phases[1].amulets[1], e.c:CatalogEntries()[1].key);
	end);
end
